#!/usr/bin/env python3
"""Verify that a new build actually reaches an already-loaded client.

Issue #76 (QE-8). Findings and the rationale for each assertion live in
`docs/quality/sw-update.md`.

The thing being tested is not "does the service worker update" — Flutter 3.47
ships no caching service worker at all. `flutter_service_worker.js` installs,
calls `skipWaiting()`, then **unregisters itself** and reloads its clients. So
there is no out-of-band update channel: what decides whether a player sees a new
build is the plain HTTP cache.

GitHub Pages serves every asset — `index.html`, `main.dart.js`, `version.json`
and `flutter_service_worker.js` included — with `cache-control: max-age=600`
(measured against production; see `docs/quality/sw-update.md`). This script
reproduces those headers exactly, publishes a second build mid-session, and
asserts what the client does on each reload path.

Assertions:

  1. Baseline: the client starts on build A.
  2. A **normal reload** inside the max-age window keeps serving build A. This is
     the staleness window, and it is asserted rather than tolerated: if it ever
     stops happening, the documented player experience is wrong.
  3. A **hard reload** immediately serves build B, proving the deploy landed and
     the client is not permanently stuck.
  4. After the max-age window closes, a **normal reload** serves build B, proving
     the window is bounded rather than infinite.

The whole cycle runs twice — a cache that updates only once would pass a
single-cycle test.

Usage:

    flutter build web --release --base-href /bust_a_move_clone/
    python3 test/quality/sw_update_check.py

Exit codes: 0 pass, 1 a named check failed, 2 the tool could not run.
"""

from __future__ import annotations

import argparse
import http.server
import json
import os
import shutil
import sys
import tempfile
import threading
import time
from functools import partial

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from release_smoke import (  # noqa: E402
    BASE_PATH,
    Chrome,
    Cdp,
    Page,
    SmokeFailure,
    find_chrome,
    log,
)

# GitHub Pages' real cache lifetime. Not a guess: measured on the live site
# 2026-10-23 for every asset this test touches.
PAGES_MAX_AGE_S = 600.0

# Long enough to observe expiry without a ten-minute test.
SHORT_MAX_AGE_S = 2.0

# Version reported by the staged build before anything is published over it.
BASE_VERSION = "1.0.0"

# Version the second build publishes. Must differ from BASE_VERSION or the
# assertions could pass without the client having changed anything.
NEXT_VERSION = "2.0.0"

DEFAULT_BUILD_DIR = "build/web"

# Reads what the *client* can currently see. Deliberately uses `fetch` with
# `cache: 'default'` — the same cache policy the app's own bundle load uses —
# so this observes the player's view, not the server's.
OBSERVE_JS = """
(async () => {
  // The document's own load of the app bundle. A fresh document starts a fresh
  // performance timeline, so the first matching entry is the build this client
  // is actually running. A fetch() from here would be a *new* request and would
  // report whatever the cache serves now, not what the page booted from.
  const entries = performance.getEntriesByType('resource')
      .filter((e) => e.name.includes('main.dart.js'));
  const app = entries.length ? entries[0] : null;

  // cache: 'reload' goes to the network, so this reports what the server
  // currently has. The default policy would report the client's cached copy,
  // which is the thing under test.
  let serverVersion = null;
  try {
    const response = await fetch('version.json', {cache: 'reload'});
    serverVersion = (await response.json()).version;
  } catch (error) {
    serverVersion = 'unreadable: ' + error;
  }

  let registrations = -1;
  let controlled = 'unknown';
  try {
    const regs = await navigator.serviceWorker.getRegistrations();
    registrations = regs.length;
    controlled = navigator.serviceWorker.controller ? 'yes' : 'no';
  } catch (error) {
    registrations = -2;
  }

  return {
    bundleBytes: app ? app.decodedBodySize : -1,
    bundleTransfer: app ? app.transferSize : -1,
    serverVersion: serverVersion,
    swRegistrations: registrations,
    swControlled: controlled,
  };
})()
"""


# --------------------------------------------------------------------------- #
# Report plumbing
# --------------------------------------------------------------------------- #


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


def describe(observation: dict, sizes: dict[int, str]) -> str:
    """One line summarising what the client runs versus what is deployed."""
    actual = observation.get("bundleBytes")
    label = sizes.get(actual, f"{actual} B")
    return (
        f"client runs build {label} "
        f"(transfer {observation.get('bundleTransfer')} B); "
        f"server serves {observation.get('serverVersion')}"
    )


def expect_bundle(observation: dict, expected_size: int, label: str,
                  sizes: dict[int, str]) -> tuple[bool, str]:
    """Assert which build the loaded document is actually running.

    Identity is the decoded size of the document's own `main.dart.js` load,
    which is exact because the two builds differ by an appended marker line.
    """
    actual = observation.get("bundleBytes")
    if actual == expected_size:
        return True, describe(observation, sizes)
    actual_label = sizes.get(actual, f"{actual} B")
    return False, (
        f"client runs build {actual_label}, wanted build {label} "
        f"({expected_size} B); server serves {observation.get('serverVersion')}"
    )


def expect_server(observation: dict, version: str) -> tuple[bool, str]:
    """Assert the deploy itself landed, independently of the client's cache."""
    actual = observation.get("serverVersion")
    if actual == version:
        return True, f"server serves {actual}"
    return False, (
        f"server serves {actual!r}, wanted {version!r} — the publish did not land"
    )


# --------------------------------------------------------------------------- #
# Server with GitHub Pages' cache behaviour
# --------------------------------------------------------------------------- #


class CachedHandler(http.server.SimpleHTTPRequestHandler):
    """Static file handler that sends a `Cache-Control` header.

    `python3 -m http.server` sends none, which leaves the browser to guess a
    lifetime heuristically — fine for eyeballing a build, useless for asserting
    a ten-minute staleness window.
    """

    max_age = PAGES_MAX_AGE_S

    def log_message(self, *_args, **_kwargs) -> None:
        pass

    def end_headers(self) -> None:
        self.send_header("Cache-Control", f"max-age={int(self.max_age)}")
        super().end_headers()


class CacheServer:
    """Serves the staged build on an ephemeral port with a chosen max-age.

    The socket binds port 0 and the assigned port is read back, so there is no
    probe-then-rebind window in which another process could steal the port.
    """

    def __init__(self, root: str, max_age: float) -> None:
        self.max_age = max_age
        # A per-server subclass keeps the max-age off the shared class: two
        # servers with different lifetimes can then run without interfering.
        handler_class = type("CachedHandler", (CachedHandler,), {"max_age": max_age})
        self._httpd = http.server.ThreadingHTTPServer(
            ("127.0.0.1", 0), partial(handler_class, directory=root)
        )
        self.port = self._httpd.server_address[1]
        self._thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)

    @property
    def base_url(self) -> str:
        return f"http://127.0.0.1:{self.port}/{BASE_PATH}/"

    def __enter__(self) -> "CacheServer":
        self._thread.start()
        return self

    def __exit__(self, *_exc) -> None:
        self._httpd.shutdown()
        self._httpd.server_close()


# --------------------------------------------------------------------------- #
# Staging and publishing
# --------------------------------------------------------------------------- #


def stage_build(source: str, root: str) -> str:
    """Copy a built bundle under `<root>/<BASE_PATH>` so the base href resolves."""
    if not os.path.isdir(source):
        raise CheckFailure(
            f"no build at {source!r} — run "
            f"`flutter build web --release --base-href /{BASE_PATH}/` first"
        )
    target = os.path.join(root, BASE_PATH)
    if os.path.isdir(target):
        shutil.rmtree(target)
    shutil.copytree(source, target)
    return target


def read_version(root: str) -> str:
    path = os.path.join(root, BASE_PATH, "version.json")
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle).get("version", "")
    except (OSError, ValueError) as error:
        raise CheckFailure(f"cannot read {path}: {error}") from error


def publish(root: str, version: str, marker: str) -> None:
    """Replace the served build with a newer one, the way a deploy would.

    Both files a stale client is judged by are changed: `version.json` (the
    app's own report) and `main.dart.js` (the bundle actually running). Touching
    only the version file would let a test pass while the client still ran the
    old code.
    """
    base = os.path.join(root, BASE_PATH)

    version_path = os.path.join(base, "version.json")
    with open(version_path, encoding="utf-8") as handle:
        data = json.load(handle)
    data["version"] = version
    with open(version_path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, separators=(",", ":"))

    bundle_path = os.path.join(base, "main.dart.js")
    with open(bundle_path, "a", encoding="utf-8") as handle:
        handle.write(f"\n// sw-update-check: {marker}\n")


# --------------------------------------------------------------------------- #
# Browser driving
# --------------------------------------------------------------------------- #


def _try_evaluate(cdp: Cdp, expression: str, default=None):
    """Evaluate, tolerating the context being torn down mid-navigation."""
    try:
        return cdp.evaluate(expression)
    except SmokeFailure:
        return default


def _load(cdp: Cdp, page: Page, timeout: float, trigger) -> None:
    """Run `trigger` to start a load, then wait for the app in the *new* document.

    `wait_for_app` looks for `flt-glass-pane`. During a reload that element is
    still present from the outgoing document for a moment, so waiting on it
    alone can return before the new page exists. A window property marks the old
    document and is gone once the new one commits.
    """
    _try_evaluate(cdp, "window.__swUpdateCheckEpoch = 1")
    trigger()

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if _try_evaluate(cdp, "typeof window.__swUpdateCheckEpoch") == "undefined":
            break
        time.sleep(0.05)
    else:
        raise CheckFailure("the page never committed a new document")

    page.wait_for_app(timeout=timeout)


def navigate(cdp: Cdp, page: Page, url: str, timeout: float) -> None:
    """Load `url` from scratch."""
    _load(cdp, page, timeout, lambda: cdp.send("Page.navigate", {"url": url}))


def reload(cdp: Cdp, page: Page, timeout: float,
           ignore_cache: bool = False) -> None:
    """Reload the current page, optionally the way Shift+Refresh does.

    `Page.reload(ignoreCache=True)` is documented as "as if the user pressed
    Shift+refresh", but headless Chrome does not honour it: the subresources
    still come from the HTTP cache and the reload is indistinguishable from a
    normal one. Disabling the cache for the duration of the load is what
    DevTools' own "Disable cache" checkbox does, and is equivalent for the
    question this test asks — can the client be forced onto the new build?

    It is *not* fully equivalent in one respect: with the cache disabled the
    responses are not written back, so this does not emulate Shift+Refresh
    leaving the new build cached. That is why the window phase asserts only
    that the hard reload reaches build B, and the expiry phase covers the
    cache updating on its own.
    """
    if not ignore_cache:
        _load(cdp, page, timeout, lambda: cdp.send("Page.reload", {}))
        return

    cdp.send("Network.enable")
    cdp.send("Network.setCacheDisabled", {"cacheDisabled": True})
    try:
        _load(cdp, page, timeout, lambda: cdp.send("Page.reload", {}))
    finally:
        cdp.send("Network.setCacheDisabled", {"cacheDisabled": False})


def observe(cdp: Cdp) -> dict:
    value = cdp.evaluate(OBSERVE_JS)
    if not isinstance(value, dict):
        raise CheckFailure(f"could not read the client's view (got {value!r})")
    return value


# --------------------------------------------------------------------------- #
# Scenarios
# --------------------------------------------------------------------------- #


def run_window_phase(build_dir: str, chrome_path: str, headed: bool,
                     timeout: float, root: str, window_max_age: float) -> list[Result]:
    """Inside a long max-age window: normal reload stays stale, hard reload does not."""
    results: list[Result] = []
    staged = stage_build(build_dir, root)
    bundle_path = os.path.join(staged, "main.dart.js")
    size_a = os.path.getsize(bundle_path)
    sizes = {size_a: "A"}

    with CacheServer(root, window_max_age) as server:
        profile = tempfile.mkdtemp(prefix="sw-update-chrome-")
        with Chrome(chrome_path, profile, 1280, 900, headless=not headed) as chrome:
            cdp = Cdp(chrome.page_websocket_url())
            try:
                cdp.send("Page.enable")
                cdp.send("Runtime.enable")
                page = Page(cdp)

                # 1. Baseline.
                result = Result(0, "Client starts on build A")
                navigate(cdp, page, server.base_url, timeout)
                first = observe(cdp)
                ok, detail = expect_bundle(first, size_a, "A", sizes)
                results.append(
                    result.passed(detail) if ok else result.failed(detail)
                )

                # 2. Publish B, then a normal reload inside the window.
                publish(root, NEXT_VERSION, "B")
                size_b = os.path.getsize(bundle_path)
                sizes[size_b] = "B"

                result = Result(
                    0,
                    f"Normal reload inside max-age={int(server.max_age)}s "
                    f"still serves build A",
                )
                reload(cdp, page, timeout)
                stale = observe(cdp)
                ok, detail = expect_bundle(stale, size_a, "A", sizes)
                server_ok, server_detail = expect_server(stale, NEXT_VERSION)
                if ok and server_ok:
                    results.append(result.passed(
                        f"{detail} — build B is deployed but unseen; a client "
                        f"can be up to {int(server.max_age)}s stale"
                    ))
                elif ok:
                    results.append(result.failed(server_detail))
                else:
                    results.append(result.failed(
                        f"{detail} — the staleness window documented in "
                        f"docs/quality/sw-update.md no longer holds"
                    ))

                # 3. Hard reload must bypass the cache.
                result = Result(0, "Hard reload immediately serves build B")
                reload(cdp, page, timeout, ignore_cache=True)
                hard = observe(cdp)
                ok, detail = expect_bundle(hard, size_b, "B", sizes)
                if ok:
                    results.append(result.passed(detail))
                else:
                    results.append(result.failed(
                        f"{detail} — a hard reload does not escape the cache, so "
                        f"a stale client has no user-side escape hatch"
                    ))

                # 4. The client is now current; report what the browser did.
                log(
                    f"  observed: service worker registrations="
                    f"{hard.get('swRegistrations')}, "
                    f"controlled={hard.get('swControlled')}"
                )
            finally:
                cdp.close()

    return results


def run_expiry_phase(build_dir: str, chrome_path: str, headed: bool,
                     timeout: float, root: str) -> list[Result]:
    """After the window closes, a normal reload picks up the new build."""
    results: list[Result] = []
    staged = stage_build(build_dir, root)
    bundle_path = os.path.join(staged, "main.dart.js")
    size_a = os.path.getsize(bundle_path)
    sizes = {size_a: "A"}

    with CacheServer(root, SHORT_MAX_AGE_S) as server:
        profile = tempfile.mkdtemp(prefix="sw-update-chrome-")
        with Chrome(chrome_path, profile, 1280, 900, headless=not headed) as chrome:
            cdp = Cdp(chrome.page_websocket_url())
            try:
                cdp.send("Page.enable")
                cdp.send("Runtime.enable")
                page = Page(cdp)

                result = Result(0, "Expiry: client starts on build A")
                navigate(cdp, page, server.base_url, timeout)
                first = observe(cdp)
                ok, detail = expect_bundle(first, size_a, "A", sizes)
                results.append(
                    result.passed(detail) if ok else result.failed(detail)
                )

                publish(root, NEXT_VERSION, "B")
                size_b = os.path.getsize(bundle_path)
                sizes[size_b] = "B"

                # Past the advertised lifetime, so the next load must revalidate.
                time.sleep(server.max_age + 1.0)

                result = Result(
                    0,
                    f"Normal reload after max-age={int(server.max_age)}s "
                    f"expires serves build B",
                )
                reload(cdp, page, timeout)
                fresh = observe(cdp)
                ok, detail = expect_bundle(fresh, size_b, "B", sizes)
                if ok:
                    results.append(result.passed(
                        f"{detail} — the window is bounded: a stale client "
                        f"cannot outlive the advertised max-age"
                    ))
                else:
                    results.append(result.failed(
                        f"{detail} — a client stayed stale past the advertised "
                        f"max-age, which means the window is unbounded"
                    ))
            finally:
                cdp.close()

    return results


# --------------------------------------------------------------------------- #
# Runner
# --------------------------------------------------------------------------- #


FINDINGS = """\
Findings (see docs/quality/sw-update.md for the full write-up):

  * GitHub Pages sends `cache-control: max-age=600` for every asset, including
    `index.html`, `version.json` and `flutter_service_worker.js`.
  * Flutter 3.47's `flutter_service_worker.js` caches nothing: it calls
    `skipWaiting()`, unregisters itself on activate, and reloads its clients.
    There is therefore no out-of-band update channel.
  * Consequence: a client can serve a superseded build for up to 600 s, and an
    already-open tab never updates itself — it stays on the old build until the
    player reloads, and a normal reload inside the window re-serves the old one.
  * A hard reload (cache bypass) is the only user-side escape hatch, which is
    why an in-app update prompt is filed as follow-up work.
"""


def report(results: list[Result]) -> int:
    log("")
    log("=" * 74)
    passed = sum(1 for r in results if r.ok)
    for index, result in enumerate(results, start=1):
        mark = "PASS" if result.ok else "FAIL"
        log(f"  [{mark}] {index}. {result.title}")
        log(f"         {result.detail}")
    log("=" * 74)
    log("")

    if passed == len(results):
        log(f"SW UPDATE CHECK PASSED — {passed}/{len(results)}")
        log("")
        log(FINDINGS)
        return 0

    log(f"SW UPDATE CHECK FAILED — {passed} of {len(results)} checks")
    for index, result in enumerate(results, start=1):
        if not result.ok:
            log(f"  * check {index}: {result.title}")
            log(f"    {result.detail}")
    return 1


def run(args: argparse.Namespace) -> int:
    build_dir = os.path.abspath(args.build_dir)
    chrome_path = find_chrome(args.chrome)
    results: list[Result] = []

    log(f"Build under test: {build_dir}")
    log(f"Chrome: {chrome_path}")
    log(f"Cycles: {args.cycles} (a cache that updates only once fails on cycle 2)")
    log("")

    root = tempfile.mkdtemp(prefix="sw-update-site-")
    try:
        for cycle in range(1, args.cycles + 1):
            log(f"--- cycle {cycle}/{args.cycles}: staleness window ---")
            results.extend(
                run_window_phase(
                    build_dir, chrome_path, args.headed, args.wait, root,
                    args.window_max_age,
                )
            )
            log(f"--- cycle {cycle}/{args.cycles}: window expiry ---")
            results.extend(
                run_expiry_phase(
                    build_dir, chrome_path, args.headed, args.wait, root
                )
            )
    finally:
        if not args.keep:
            shutil.rmtree(root, ignore_errors=True)

    return report(results)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify a new build reaches an already-loaded client."
    )
    parser.add_argument("--build-dir", default=DEFAULT_BUILD_DIR,
                        help=f"built web bundle to serve (default: {DEFAULT_BUILD_DIR})")
    parser.add_argument("--cycles", type=int, default=2,
                        help="how many full update cycles to run (default: 2)")
    parser.add_argument("--window-max-age", type=float, default=PAGES_MAX_AGE_S,
                        help="cache lifetime the server advertises during the "
                             "staleness-window phase (default: %(default)s, which "
                             "is what GitHub Pages sends). Set it to 0 to confirm "
                             "this check can fail.")
    parser.add_argument("--wait", type=float, default=45.0,
                        help="seconds to allow Flutter to boot (default: 45)")
    parser.add_argument("--chrome", default=None,
                        help="path to a Chrome/Chromium binary")
    parser.add_argument("--headed", action="store_true",
                        help="run Chrome with a visible window")
    parser.add_argument("--keep", action="store_true",
                        help="keep the staged site directory for inspection")
    args = parser.parse_args(argv)

    try:
        return run(args)
    except CheckFailure as error:
        log("")
        log(f"SW UPDATE CHECK FAILED — {error}")
        return 1
    except SmokeFailure as error:
        log("")
        log(f"SW UPDATE CHECK COULD NOT RUN — {error}")
        return 2
    except KeyboardInterrupt:
        log("")
        log("Interrupted.")
        return 2


if __name__ == "__main__":
    sys.exit(main())
