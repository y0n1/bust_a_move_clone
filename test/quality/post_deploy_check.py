#!/usr/bin/env python3
"""Post-deploy check — proves the *live* site works, from outside.

A green deploy workflow only proves Pages accepted an artifact. This script
closes that gap: it points at the deployed URL and asserts what a visitor gets.

It is deliberately narrower than `release_smoke.py`. That suite builds the
artifact and drives the §9 critical journey; this one touches only what a
deploy can break. Full gameplay regression stays with the smoke suite.

Usage
-----
    python3 test/quality/post_deploy_check.py
    python3 test/quality/post_deploy_check.py --url https://example.test/site/
    python3 test/quality/post_deploy_check.py --headed

Stdlib only — the CDP plumbing (`Chrome`, `Cdp`, `Page`) is imported from
`release_smoke.py` in this directory so the two tools cannot drift apart.

What it checks
--------------
  1. The site root answers **HTTP 200** with an HTML content type.
  2. `version.json` answers 200 and its `version` **matches the release**.
  3. `manifest.json` answers 200, and every icon it declares plus `favicon.png`
     answers 200 **with a real PNG signature**.
  4. Headless Chrome loads the site, Flutter boots, the semantics tree appears,
     the **start screen** renders and **PLAY** is reachable, with **no blocking
     console errors**.

Step 3 exists because a console check cannot see it. Browser-level manifest and
image fetches are not delivered to the page's CDP console session, so a site
serving 404 icons logs nothing — which is exactly how #95 reached production
with the smoke suite reporting 10/10.

Timing
------
A freshly published Pages deployment is not instantly visible on the CDN. Every
network assertion retries with backoff until `--wait` seconds elapse rather than
relying on a fixed sleep, so a slow edge does not flake the release.

Exit codes
----------
  0  every check passed
  1  a check failed (the failing check is named)
  2  the tool itself could not run (no Chrome, bad arguments)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from release_smoke import (  # noqa: E402  - path is set up above
    Chrome,
    Cdp,
    Page,
    SmokeFailure,
    find_chrome,
    log,
)

DEFAULT_URL = "https://y0n1.github.io/bust_a_move_clone/"
DEFAULT_WAIT_S = 180.0
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
USER_AGENT = "bust-a-move-post-deploy-check/1.0"


class CheckFailure(SmokeFailure):
    """A named check failed."""


class Result:
    def __init__(self, number: int, title: str) -> None:
        self.number = number
        self.title = title
        self.ok = False
        self.detail = ""

    def passed(self, detail: str) -> "Result":
        self.ok = True
        self.detail = detail
        return self

    def failed(self, detail: str) -> "Result":
        self.ok = False
        self.detail = detail
        return self


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #


def http_get(url: str, timeout: float = 20.0) -> tuple[int, bytes, dict]:
    """Return `(status, body, headers)` for `url`.

    A non-2xx response is returned rather than raised: the caller decides
    whether a 404 is a retryable propagation lag or a real failure.
    """
    request = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Cache-Control": "no-cache"}
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read(), _lower_headers(response.headers)
    except urllib.error.HTTPError as error:
        return error.code, error.read(), _lower_headers(error.headers)
    except OSError as error:
        raise CheckFailure(f"could not reach {url}: {error}") from error


def _lower_headers(headers) -> dict:
    """Lower-case header names so lookups do not depend on server casing.

    GitHub Pages sends `Content-Type`; Python's `http.server` sends
    `Content-type`. `dict(headers)` keeps whichever arrived, so a plain
    `headers['Content-Type']` silently misses one of them.
    """
    if not headers:
        return {}
    return {name.lower(): value for name, value in headers.items()}


def fetch_until(url: str, accept, wait_s: float, what: str):
    """Poll `url` until `accept(status, body, headers)` is truthy.

    Returns the accepting `(status, body, headers)`. Raises with the *last*
    observed state, which is what an operator needs to see: a 404 that never
    became a 200 is a missing file, a 200 whose body never changed is a stale
    deployment, and the message distinguishes them.

    A connection error is retried rather than raised. Mid-deploy, a Pages edge
    can reset or refuse a connection for a few seconds; treating that as a
    terminal failure would flake the release exactly when the check matters.
    """
    deadline = time.monotonic() + wait_s
    attempt = 0
    last_error: str | None = None
    while True:
        attempt += 1
        try:
            last = http_get(url)
        except CheckFailure as error:
            # Transient: remember it and keep trying inside the same budget.
            last_error = str(error)
            if time.monotonic() >= deadline:
                raise CheckFailure(
                    f"{what} was unreachable after {attempt} attempts over "
                    f"{wait_s:.0f}s (last: {last_error})"
                ) from error
            time.sleep(min(2.0 * attempt, 15.0))
            continue
        last_error = None
        if accept(*last):
            return last
        if time.monotonic() >= deadline:
            status, body, _ = last
            preview = body[:200].decode("utf-8", "replace").replace("\n", " ")
            raise CheckFailure(
                f"{what} never became valid after {attempt} attempts over "
                f"{wait_s:.0f}s (last: HTTP {status}, body starts {preview!r})"
            )
        # Backoff, capped: Pages usually propagates in seconds, but the first
        # request after a deploy can take longer than the rest.
        time.sleep(min(2.0 * attempt, 15.0))


# --------------------------------------------------------------------------- #
# Version
# --------------------------------------------------------------------------- #


def pubspec_version(repo_root: str) -> str | None:
    """Read `version:` from pubspec.yaml, dropping the build number.

    `1.0.0+1` is one release with build 1; `version.json` reports them as
    separate fields, so only the release part is compared.
    """
    path = os.path.join(repo_root, "pubspec.yaml")
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                match = re.match(r"^version:\s*(\S+)\s*$", line)
                if match:
                    return match.group(1).split("+")[0]
    except OSError:
        return None
    return None


def parse_version_json(body: bytes) -> tuple[str, str]:
    try:
        payload = json.loads(body)
    except ValueError as error:
        raise CheckFailure(f"version.json is not JSON: {error}") from error
    version = str(payload.get("version", "")).strip()
    build = str(payload.get("build_number", "")).strip()
    if not version:
        raise CheckFailure(f"version.json has no 'version' field: {payload!r}")
    return version, build


# --------------------------------------------------------------------------- #
# PNG
# --------------------------------------------------------------------------- #


def png_size(body: bytes) -> tuple[int, int] | None:
    """Return `(width, height)` for a PNG body, or None if it is not one.

    Mirrors `test/web_assets_test.dart` so the deployed site and the shipped
    source are held to the same definition of "is a PNG".
    """
    if len(body) < 24 or not body.startswith(PNG_SIGNATURE):
        return None
    if body[12:16] != b"IHDR":
        return None
    width = int.from_bytes(body[16:20], "big")
    height = int.from_bytes(body[20:24], "big")
    return width, height


def describe_body(body: bytes) -> str:
    """Name what was actually served, for the failure message."""
    if body.startswith(b"iVBORw0KGgo"):
        return "base64 text, not a PNG (this is the #95 defect)"
    head = body[:16]
    if head.startswith(b"<"):
        return f"HTML/XML, not a PNG (starts {head.decode('utf-8', 'replace')!r})"
    return f"{len(body)} bytes starting {head!r}"


# --------------------------------------------------------------------------- #
# Browser
# --------------------------------------------------------------------------- #


def check_browser(url: str, chrome_path: str, headed: bool,
                  wait_s: float, artifacts_dir: str | None) -> Result:
    """Load the site and assert the start screen is reachable."""
    result = Result(4, "App loads, start screen renders, no blocking console errors")
    profile = tempfile.mkdtemp(prefix="post-deploy-chrome-")
    try:
        with Chrome(chrome_path, profile, 1280, 900, headless=not headed) as chrome:
            cdp = Cdp(chrome.page_websocket_url())
            try:
                page = Page(cdp)
                cdp.send("Page.enable")
                cdp.send("Log.enable")
                cdp.send("Runtime.enable")
                cdp.send("Page.navigate", {"url": url})

                # Flutter has to boot from the CDN; a cold Pages edge plus a
                # cold CanvasKit fetch is slower than a local build.
                page.wait_for_app(timeout=max(wait_s, 45.0))
                page.enable_semantics()
                text = page.text()

                if "PLAY" not in text.upper():
                    raise CheckFailure(
                        f"start screen never offered PLAY (saw: {text[:300]!r})"
                    )

                # Let late errors land: a console error raised during the first
                # frames arrives after the screen is already readable.
                cdp.pump_events(1.5)
                if cdp.console_errors:
                    raise CheckFailure(
                        "blocking console errors: "
                        + "; ".join(cdp.console_errors[:5])
                    )
            finally:
                if artifacts_dir and cdp.console_errors:
                    os.makedirs(artifacts_dir, exist_ok=True)
                    with open(os.path.join(artifacts_dir, "console.log"),
                              "w", encoding="utf-8") as handle:
                        handle.write("\n".join(cdp.console_errors))
                cdp.close()
    except SmokeFailure as error:
        return result.failed(str(error))
    return result.passed("start screen reachable, 0 blocking console errors")


# --------------------------------------------------------------------------- #
# Runner
# --------------------------------------------------------------------------- #


def run(args: argparse.Namespace) -> int:
    base = args.url if args.url.endswith("/") else args.url + "/"
    repo_root = os.path.abspath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
    )
    expected = args.expect_version or pubspec_version(repo_root)
    results: list[Result] = []
    observed: dict[str, str] = {}

    log(f"Post-deploy check against {base}")
    if expected:
        log(f"Expected version: {expected}")
    log("")

    # -- 1. site root ------------------------------------------------------
    result = Result(1, "Site root answers HTTP 200")
    try:
        status, body, headers = fetch_until(
            base,
            lambda s, b, h: s == 200 and b"<html" in b.lower(),
            args.wait, "the site root",
        )
        content_type = headers.get("content-type", "unknown")
        if "html" not in content_type.lower():
            raise CheckFailure(
                f"the site root served {content_type!r}, not HTML — Pages is "
                f"returning something other than the app"
            )
        observed["content_type"] = content_type
        result.passed(f"HTTP {status}, {content_type}, {len(body)} bytes")
    except SmokeFailure as error:
        result.failed(str(error))
    results.append(result)
    if not result.ok:
        return report(results, base, expected, observed)

    # -- 2. version.json ---------------------------------------------------
    result = Result(2, "version.json matches the released version")
    try:
        if not expected:
            # Without a version to compare against this check cannot fail, and
            # a check that cannot fail is not a gate. Refuse rather than pass.
            raise CheckFailure(
                "no expected version: pass --expect-version or run from a "
                "checkout whose pubspec.yaml declares one"
            )
        status, body, _ = fetch_until(
            base + "version.json",
            lambda s, b, h: s == 200 and b.strip().startswith(b"{"),
            args.wait, "version.json",
        )
        version, build = parse_version_json(body)
        observed["version"] = f"{version}+{build}" if build else version
        if version != expected:
            raise CheckFailure(
                f"version.json reports {version!r} but the release is "
                f"{expected!r} — the deploy served a stale or wrong artifact"
            )
        result.passed(f"HTTP {status}, version {version!r}, build {build!r}")
    except SmokeFailure as error:
        result.failed(str(error))
    results.append(result)

    # -- 3. manifest and icons --------------------------------------------
    result = Result(3, "Manifest and every declared icon are real PNGs")
    try:
        status, body, _ = fetch_until(
            base + "manifest.json",
            lambda s, b, h: s == 200 and b.strip().startswith(b"{"),
            args.wait, "manifest.json",
        )
        manifest = json.loads(body)
        icons = manifest.get("icons") or []
        if not icons:
            raise CheckFailure("manifest.json declares no icons")

        checked = []
        for icon in icons:
            src = icon.get("src")
            if not src:
                raise CheckFailure(f"manifest icon entry has no src: {icon!r}")
            icon_url = base + src.lstrip("./")
            icon_status, icon_body, _ = http_get(icon_url)
            if icon_status != 200:
                raise CheckFailure(
                    f"{src} declared in the manifest answers HTTP {icon_status}"
                )
            size = png_size(icon_body)
            if size is None:
                raise CheckFailure(
                    f"{src} is not a PNG: {describe_body(icon_body)}"
                )
            declared = icon.get("sizes", "")
            match = re.match(r"^(\d+)x(\d+)$", declared)
            if match and size != (int(match.group(1)), int(match.group(2))):
                raise CheckFailure(
                    f"{src} is {size[0]}x{size[1]} but the manifest declares "
                    f"{declared}"
                )
            checked.append(f"{src} {size[0]}x{size[1]}")

        favicon_status, favicon_body, _ = http_get(base + "favicon.png")
        if favicon_status != 200:
            raise CheckFailure(
                f"favicon.png answers HTTP {favicon_status}"
            )
        favicon = png_size(favicon_body)
        if favicon is None:
            raise CheckFailure(
                f"favicon.png is not a PNG: {describe_body(favicon_body)}"
            )
        checked.append(f"favicon.png {favicon[0]}x{favicon[1]}")
        observed["icons"] = str(len(checked))
        result.passed("manifest HTTP %d; %s" % (status, ", ".join(checked)))
    except (SmokeFailure, ValueError) as error:
        result.failed(str(error))
    results.append(result)

    # -- 4. browser --------------------------------------------------------
    try:
        chrome_path = find_chrome(args.chrome)
    except SmokeFailure as error:
        log(f"CANNOT RUN: {error}")
        return 2
    results.append(
        check_browser(base, chrome_path, args.headed, args.wait,
                      args.artifacts_dir)
    )

    return report(results, base, expected, observed)


def report(results: list[Result], base: str, expected: str | None,
           observed: dict[str, str]) -> int:
    failed = [r for r in results if not r.ok]
    log("")
    for result in results:
        mark = "PASS" if result.ok else "FAIL"
        log(f"  [{mark}] {result.number}. {result.title}")
        if result.detail:
            log(f"         {result.detail}")
    log("")

    if failed:
        log(f"POST-DEPLOY CHECK FAILED — {len(failed)} of {len(results)} checks")
        for result in failed:
            log(f"  * check {result.number}: {result.title}")
            log(f"    {result.detail}")
        return 1

    log(f"POST-DEPLOY CHECK PASSED — {len(results)}/{len(results)}")
    if expected:
        log("")
        log("Deployment-log row (paste into docs/ops/deployment-log.md):")
        log("")
        log(log_row(base, expected, observed))
    return 0

def log_row(base: str, version: str, observed: dict[str, str]) -> str:
    """Render the deployment-log table row for this run.

    Generated rather than hand-written so the evidence in the log is the
    evidence the check actually measured. Only ever called from `report()`
    after every check passed — there is deliberately no way to print a row
    without having run the checks, because a log entry that asserts unmeasured
    results is worse than no entry.
    """
    stamp = time.strftime("%Y-%m-%d %H:%M", time.gmtime())
    served = observed.get("version", version)
    icons = observed.get("icons", "?")
    return (
        f"| {stamp} | {served} | — | — | — | "
        f"✅ post-deploy check 4/4: HTTP 200; version.json {served}; "
        f"{icons} icons real PNGs; start screen reachable, 0 console errors "
        f"({base}) | DevOps | Generated by "
        f"`test/quality/post_deploy_check.py` (OPS-4) |"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify the deployed site, after the deploy workflow ran."
    )
    parser.add_argument("--url", default=os.environ.get("DEPLOY_URL", DEFAULT_URL),
                        help=f"site root to check (default: {DEFAULT_URL})")
    parser.add_argument("--expect-version", default=None,
                        help="released version to require in version.json "
                             "(default: read from pubspec.yaml)")
    parser.add_argument("--wait", type=float, default=DEFAULT_WAIT_S,
                        help=f"seconds to keep retrying network checks while "
                             f"Pages propagates (default: {DEFAULT_WAIT_S:.0f})")
    parser.add_argument("--chrome", default=None,
                        help="path to a Chrome/Chromium binary")
    parser.add_argument("--headed", action="store_true",
                        help="run Chrome with a visible window")
    parser.add_argument("--artifacts-dir", default=None,
                        help="where to write console.log on failure")
    args = parser.parse_args(argv)

    try:
        return run(args)
    except KeyboardInterrupt:
        log("")
        log("Interrupted.")
        return 2


if __name__ == "__main__":
    sys.exit(main())
