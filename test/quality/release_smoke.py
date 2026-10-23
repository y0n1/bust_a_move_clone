#!/usr/bin/env python3
"""Release smoke suite — runs the §9 critical journey against the built artifact.

This automates the manual release smoke path in `docs/quality/test-strategy.md`
§9. It drives the *production web build* in a real browser and asserts on what a
player can actually observe.

Usage
-----
    python3 test/quality/release_smoke.py

One command, zero third-party dependencies (stdlib only — the CDP WebSocket
client is vendored at the bottom of this file). The script:

  1. builds `build/web` if it is missing (skip with `--no-build`),
  2. stages it under `<tmp>/bust_a_move_clone/` and serves the parent directory,
     because the Pages base href is `/bust_a_move_clone/` — serving `build/web`
     at the root yields a blank page,
  3. launches headless Chrome and drives it over the DevTools Protocol,
  4. runs the ten smoke steps and prints a PASS/FAIL table,
  5. on failure writes `screenshot.png`, `trace.json` and `console.log` to
     `build/smoke-artifacts/<utc>/` and exits non-zero.

How the app is observed
-----------------------
`build/web` is a **release** CanvasKit build: no VM service, and the game itself
is painted into a canvas with no DOM. The suite therefore observes the artifact
from outside, exactly as a release gate should:

* **HUD and overlay state** are read from Flutter's semantics tree
  (`flt-semantics-placeholder` -> `flt-semantics`), which carries `SCORE`,
  `LIVES`, `LEVEL`, `NEXT` and the win/lose overlays as text.
* **Input** is dispatched as real browser mouse events, so the app sees genuine
  pointer traffic rather than synthesised DOM clicks.

Two consequences are stated plainly rather than papered over:

* **Aim guide and wall bounce are canvas-only** — no observable surface reports
  them. Steps 2 and 3 are therefore *behavioural*: they prove the pointer is
  accepted and the shot resolves, while the geometry behind them is owned by
  the engine unit tests that run on every pull request.
* **The board is not seedable.** `GameViewModel` uses an unseeded
  `math.Random`, and there is no `--dart-define` or query-parameter hook. A
  match-3 cannot be forced, so the suite fires until one occurs within a bounded
  shot budget and reports how many shots it took. Measured over 180 shots across
  several boards, a shot pops about 20-25% of the time; the budget is sized so
  that a total whiff is far less likely than a hardware fault. A chain reaction
  is rarer still — it needs two pops in a row — so it gets its own, larger
  budget, sized from the measured wait (see `CHAIN_SHOT_BUDGET`).

Scoring and chaining
--------------------
`lib/game/engine.dart` scores a pop as `150 * (groupSize - 1) * combo` and adds
`50` per bubble for a detached cluster that falls. Two inferences that look
sound are not, and the suite does not make them:

* a single-shot delta of `>= 600` does **not** prove a chain — a five-bubble
  pop at combo 1 scores exactly `600`;
* a delta that is not a multiple of `100` does **not** prove a drop — a
  four-bubble pop at combo 1 scores `450`.

A chain is therefore proven from the HUD instead: `ScoreDisplay` renders
`COMBO xN` while `combo >= 2`, which only happens on a second consecutive pop.
A detached-cluster drop has no observable surface at all — its score is added
to a pop's, and the pop's own size is not observable — so it is covered by the
engine unit tests that run on every pull request, not here.

Screenshots
-----------
`Page.captureScreenshot` returns a frozen frame in headless Chrome with
CanvasKit (verified: two captures at different aim positions were byte
identical). Failure screenshots are therefore taken from
`Page.startScreencast`, whose frames do track the canvas.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

# The Pages base href. The artifact must be served under this directory name.
BASE_PATH = "bust_a_move_clone"

# §14 target: smoke suite duration < 5 minutes. Measured from the moment the
# browser starts, so a slow `flutter build web` does not eat the game's budget.
TIME_BUDGET_S = 300.0

# A release web build measured 15-28s locally; the ceiling only exists so a
# wedged build fails instead of hanging the run forever.
BUILD_TIMEOUT_S = 900.0

# Shots fired while hunting for a match-3 and then a chain/drop.
#
# A shot pops about 20-25% of the time (measured over 180 shots; a life loss
# rebuilds the board every three or four shots, so a hunt spans several boards).
# At 25%, 24 shots whiffed 1 time in ~1000 — which happened — while 40 shots
# whiff 1 time in ~100,000. Worst case a hunt costs ~45s, well inside
# `TIME_BUDGET_S`.
DEFAULT_MAX_SHOTS = 40

# A chain needs two consecutive pops, so its chance is bounded by the pop rate
# rather than equal to it and the wait is heavy-tailed: measured at 4, 8, 29 and
# 77 shots to the first chain. The chain hunt therefore gets its own, larger
# budget — 80 shots whiff about 1 run in 80 at the observed rates, and the
# worst case still leaves the whole suite inside `TIME_BUDGET_S`.
CHAIN_SHOT_BUDGET = 80

# Level 1 descends every shot (`descentInterval: 1`), and the projectile
# resolves in well under a second at `projectileSpeed: 0.6`.
DEFAULT_SETTLE_S = 0.9

CHROME_CANDIDATES = (
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
)

HUD_PATTERNS = {
    "score": re.compile(r"SCORE\s+(-?\d+)"),
    "lives": re.compile(r"LIVES\s+(-?\d+)"),
    "level": re.compile(r"LEVEL\s+(\d+)"),
}

# `ScoreDisplay` renders `COMBO xN` only while `state.combo >= 2`, i.e. only
# while a pop streak is running, so the text is present exactly on the shots
# that chained.
COMBO_PATTERN = re.compile(r"COMBO\s*\u00d7\s*(\d+)")

# Console noise that must not fail the run: a missing favicon is a Pages
# concern, not a game defect.
BENIGN_CONSOLE = (
    "favicon",
    "Failed to load resource: the server responded with a status of 404",
)


# --------------------------------------------------------------------------- #
# Small helpers
# --------------------------------------------------------------------------- #


class SmokeFailure(Exception):
    """A smoke step failed. Carries the diagnostic shown to the operator."""


def log(message: str = "") -> None:
    print(message, flush=True)


def find_chrome(explicit: str | None) -> str:
    for candidate in (explicit, os.environ.get("CHROME")):
        if candidate:
            resolved = shutil.which(candidate) or candidate
            if os.path.exists(resolved):
                return resolved
            raise SmokeFailure(f"Chrome not found at {candidate!r}")
    for candidate in CHROME_CANDIDATES:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise SmokeFailure(
        "No Chrome/Chromium binary found. Install one or pass --chrome PATH "
        "(or set CHROME)."
    )


# --------------------------------------------------------------------------- #
# Static server — serves the staged artifact so the base href resolves
# --------------------------------------------------------------------------- #


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args, **_kwargs) -> None:  # silence request spam
        pass


class StaticServer:
    """Serves the staged artifact on an ephemeral port.

    The socket binds port 0 and the assigned port is read back, so there is no
    probe-then-rebind window in which another process could steal the port.
    """

    def __init__(self, root: str) -> None:
        handler = partial(QuietHandler, directory=root)
        self._httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.port = self._httpd.server_address[1]
        self._thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)

    @property
    def base_url(self) -> str:
        return f"http://127.0.0.1:{self.port}/{BASE_PATH}/"

    def __enter__(self) -> "StaticServer":
        self._thread.start()
        return self

    def __exit__(self, *_exc) -> None:
        self._httpd.shutdown()
        self._httpd.server_close()


# --------------------------------------------------------------------------- #
# Chrome launcher
# --------------------------------------------------------------------------- #


class Chrome:
    def __init__(self, binary: str, profile_dir: str, width: int, height: int,
                 headless: bool = True) -> None:
        self.binary = binary
        self.profile_dir = profile_dir
        self.width = width
        self.height = height
        self.headless = headless
        self.port = 0
        self._proc: subprocess.Popen | None = None

    def __enter__(self) -> "Chrome":
        args = [
            self.binary,
            "--remote-debugging-port=0",
            f"--user-data-dir={self.profile_dir}",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-background-networking",
            "--disable-component-update",
            "--disable-default-apps",
            "--disable-extensions",
            "--disable-sync",
            "--metrics-recording-only",
            "--mute-audio",
            "--hide-scrollbars",
            f"--window-size={self.width},{self.height}",
        ]
        if self.headless:
            args.append("--headless=new")
        # `--no-sandbox` is needed as root, and it pairs with
        # `--disable-dev-shm-usage`: Chrome's default 64 MB /dev/shm is too
        # small in containers and crashes tabs mid-run.
        if os.environ.get("CHROME_NO_SANDBOX") or (
            hasattr(os, "geteuid") and os.geteuid() == 0
        ):
            args.extend(["--no-sandbox", "--disable-dev-shm-usage"])
        args.append("about:blank")

        self._proc = subprocess.Popen(
            args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        try:
            self.port = self._wait_for_port()
        except BaseException:
            # `__exit__` only runs when `__enter__` returned, so without this a
            # startup failure (or a Ctrl-C) leaks the browser process.
            self._terminate()
            raise
        return self

    def _terminate(self) -> None:
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
            try:
                self._proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self._proc.kill()
                self._proc.wait(timeout=10)

    def __exit__(self, *_exc) -> None:
        self._terminate()

    def _wait_for_port(self, timeout: float = 30.0) -> int:
        # Chrome writes "<port>\n<browser ws path>" once the DevTools endpoint
        # is listening. Reading it avoids guessing a fixed port.
        port_file = os.path.join(self.profile_dir, "DevToolsActivePort")
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self._proc and self._proc.poll() is not None:
                raise SmokeFailure(
                    f"Chrome exited immediately (code {self._proc.returncode})"
                )
            if os.path.exists(port_file):
                with open(port_file, encoding="utf-8") as handle:
                    first = handle.readline().strip()
                if first.isdigit():
                    return int(first)
            time.sleep(0.05)
        raise SmokeFailure("Timed out waiting for Chrome's DevTools port")

    def page_websocket_url(self, timeout: float = 20.0) -> str:
        deadline = time.monotonic() + timeout
        url = f"http://127.0.0.1:{self.port}/json/list"
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(url, timeout=5) as response:
                    targets = json.loads(response.read())
            except OSError:
                targets = []
            for target in targets:
                if target.get("type") == "page" and target.get(
                    "webSocketDebuggerUrl"
                ):
                    return target["webSocketDebuggerUrl"]
            time.sleep(0.1)
        raise SmokeFailure("No debuggable page target appeared in Chrome")


# --------------------------------------------------------------------------- #
# CDP client
# --------------------------------------------------------------------------- #


class CdpError(SmokeFailure):
    pass


class Cdp:
    def __init__(self, ws_url: str) -> None:
        scheme, _, rest = ws_url.partition("://")
        if scheme != "ws":
            raise SmokeFailure(f"Expected a ws:// url, got {ws_url!r}")
        hostport, _, path = rest.partition("/")
        host, _, port = hostport.partition(":")
        self.ws = WebSocket(host, int(port), "/" + path)
        self._next_id = 0
        self.console_errors: list[str] = []
        self._frame: bytes | None = None
        self._pending_acks: list[int] = []
        self._trace_events: list[dict] = []

    # -- plumbing ----------------------------------------------------------

    def close(self) -> None:
        """Close the DevTools socket so Chrome can shut down promptly."""
        try:
            self.ws.close()
        except Exception:  # noqa: BLE001 - teardown must not raise
            pass

    def send(self, method: str, params: dict | None = None,
             timeout: float = 30.0) -> dict:
        self._next_id += 1
        message_id = self._next_id
        try:
            self.ws.send_text(
                json.dumps(
                    {"id": message_id, "method": method, "params": params or {}}
                )
            )
        except OSError as error:
            raise SmokeFailure(
                f"the DevTools connection died sending {method}: {error}"
            ) from error
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise SmokeFailure(f"CDP timeout waiting for {method}")
            self.ws.sock.settimeout(remaining)
            try:
                message = json.loads(self.ws.recv_text())
            except (OSError, ValueError) as error:
                # A dead or wedged browser surfaces as a socket error or a
                # truncated frame, not as a CDP error. Normalise it so `run()`
                # can capture artifacts instead of dying with a traceback.
                raise SmokeFailure(
                    f"the DevTools connection failed waiting for {method}: {error}"
                ) from error
            if message.get("id") == message_id:
                if "error" in message:
                    raise CdpError(f"{method}: {message['error']}")
                return message.get("result", {})
            self._record(message)

    def _record(self, message: dict) -> None:
        method = message.get("method")
        params = message.get("params", {})
        if method == "Page.screencastFrame":
            self._frame = base64.b64decode(params["data"])
            self._pending_acks.append(params["sessionId"])
        elif method == "Log.entryAdded":
            entry = params.get("entry", {})
            if entry.get("level") == "error":
                text = f"{entry.get('source', '?')}: {entry.get('text', '')}"
                if not any(benign in text for benign in BENIGN_CONSOLE):
                    self.console_errors.append(text)
        elif method == "Runtime.exceptionThrown":
            details = params.get("exceptionDetails", {})
            description = (
                details.get("exception", {}).get("description")
                or details.get("text")
                or "uncaught exception"
            )
            self.console_errors.append(f"exception: {description}")
        elif method == "Tracing.dataCollected":
            # Trace chunks can arrive while another command is in flight; keep
            # them so `trace.json` is complete rather than truncated.
            self._trace_events.extend(params.get("value", []))

    def _ack_frames(self) -> None:
        while self._pending_acks:
            session_id = self._pending_acks.pop(0)
            try:
                self.send("Page.screencastFrameAck", {"sessionId": session_id})
            except SmokeFailure:
                return

    def pump_events(self, seconds: float) -> None:
        """Read and dispatch events for `seconds` without expecting a reply."""
        deadline = time.monotonic() + seconds
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            try:
                self.ws.sock.settimeout(remaining)
                message = json.loads(self.ws.recv_text())
            except (OSError, SmokeFailure):
                break
            self._record(message)
        self._ack_frames()

    # -- convenience -------------------------------------------------------

    def evaluate(self, expression: str, timeout: float = 30.0):
        result = self.send(
            "Runtime.evaluate",
            {"expression": expression, "returnByValue": True,
             "awaitPromise": True},
            timeout=timeout,
        )
        if "exceptionDetails" in result:
            raise SmokeFailure(f"JS exception: {result['exceptionDetails']}")
        return result.get("result", {}).get("value")

    def start_screencast(self) -> None:
        self.send("Page.startScreencast", {"format": "png", "everyNthFrame": 1})

    def live_screenshot(self, wait: float = 1.5) -> bytes:
        """Return a current frame.

        `Page.captureScreenshot` returns a frozen frame under headless
        CanvasKit, so screencast frames are used instead. Falls back to
        `captureScreenshot` if no screencast frame arrives.
        """
        self._frame = None
        deadline = time.monotonic() + wait
        while time.monotonic() < deadline and self._frame is None:
            self.pump_events(0.25)
        if self._frame is not None:
            return self._frame
        data = self.send("Page.captureScreenshot", {"format": "png"}, timeout=60)
        return base64.b64decode(data["data"])

    def mouse(self, event_type: str, x: float, y: float,
              buttons: int = 0, button: str = "none") -> None:
        self.send(
            "Input.dispatchMouseEvent",
            {"type": event_type, "x": x, "y": y, "button": button,
             "buttons": buttons, "clickCount": 1 if button == "left" else 0,
             "pointerType": "mouse"},
        )

    def move(self, x: float, y: float) -> None:
        self.mouse("mouseMoved", x, y)

    def click(self, x: float, y: float) -> None:
        self.move(x, y)
        time.sleep(0.03)
        self.mouse("mousePressed", x, y, buttons=1, button="left")
        time.sleep(0.04)
        self.mouse("mouseReleased", x, y, buttons=0, button="left")

    def start_trace(self) -> None:
        self.send(
            "Tracing.start",
            {
                "categories": (
                    "devtools.timeline,blink.user_timing,"
                    "disabled-by-default-devtools.timeline"
                ),
                "transferMode": "ReportEvents",
            },
        )

    def stop_trace(self) -> list[dict]:
        self.send("Tracing.end")
        collected: list[dict] = list(self._trace_events)
        self._trace_events.clear()
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            self.ws.sock.settimeout(max(0.1, deadline - time.monotonic()))
            try:
                message = json.loads(self.ws.recv_text())
            except (OSError, ValueError):
                return collected
            method = message.get("method")
            if method == "Tracing.dataCollected":
                collected.extend(message["params"]["value"])
            elif method == "Tracing.tracingComplete":
                return collected
            else:
                self._record(message)
        return collected


# --------------------------------------------------------------------------- #
# Page interaction — semantics tree, HUD parsing
# --------------------------------------------------------------------------- #

ENABLE_SEMANTICS_JS = """
(() => {
  const placeholder = document.querySelector('flt-semantics-placeholder');
  if (placeholder) { placeholder.click(); return true; }
  return document.querySelectorAll('flt-semantics').length > 0;
})()
"""

PAGE_TEXT_JS = "document.body.innerText.replace(/\\s+/g, ' ').trim()"

# Flutter puts each semantics node's label in aria-label. Container nodes are
# worth reading too: an overlay's headline is painted on the canvas, so it
# survives only as the container's aria-label.
SEMANTIC_LABELS_JS = """
(() => [...document.querySelectorAll('flt-semantics')]
  .map(n => n.getAttribute('aria-label') || '')
  .join('\\n'))()
"""

# Only role="button" nodes are click targets. Matching on text alone finds the
# overlay's container, whose only DOM text is its button's label — clicking it
# lands on the overlay body and does nothing.
FIND_CLICKABLE_JS = """
((label) => {
  const nodes = [...document.querySelectorAll('flt-semantics[role="button"]')];
  const match = nodes.find(n => (n.getAttribute('aria-label') || '').trim() === label)
             || nodes.find(n => (n.innerText || '').trim() === label);
  if (!match) return null;
  const rect = match.getBoundingClientRect();
  return {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2,
          w: rect.width, h: rect.height};
})
"""

VIEWPORT_JS = """
(() => {
  const view = document.querySelector('flutter-view') || document.body;
  const rect = view.getBoundingClientRect();
  return {x: rect.x, y: rect.y, w: rect.width, h: rect.height};
})()
"""


class Page:
    """The app under test, observed the way a player observes it."""

    def __init__(self, cdp: Cdp) -> None:
        self.cdp = cdp

    def wait_for_app(self, timeout: float = 45.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.cdp.evaluate("!!document.querySelector('flt-glass-pane')"):
                return
            time.sleep(0.1)
        raise SmokeFailure("Flutter did not boot (no flt-glass-pane in the DOM)")

    def enable_semantics(self, timeout: float = 15.0) -> None:
        self.cdp.evaluate(ENABLE_SEMANTICS_JS)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.cdp.evaluate(
                "document.querySelectorAll('flt-semantics').length"
            ) > 0:
                return
            time.sleep(0.1)
        raise SmokeFailure(
            "Flutter's semantics tree never appeared; the HUD is unreadable"
        )

    def text(self) -> str:
        return self.cdp.evaluate(PAGE_TEXT_JS) or ""

    def find(self, label: str) -> dict | None:
        return self.cdp.evaluate(
            f"({FIND_CLICKABLE_JS.strip()})({json.dumps(label)})"
        )

    def click_label(self, *labels: str) -> str:
        for label in labels:
            target = self.find(label)
            if target:
                self.cdp.click(target["x"], target["y"])
                return label
        raise SmokeFailure(
            f"None of {labels!r} are clickable in the semantics tree "
            f"(screen: {self.text()!r})"
        )

    def viewport(self) -> dict:
        return self.cdp.evaluate(VIEWPORT_JS)

    def hud(self) -> dict:
        """Parse the HUD out of the semantics tree."""
        text = self.text()
        values = {}
        for name, pattern in HUD_PATTERNS.items():
            match = pattern.search(text)
            if not match:
                raise SmokeFailure(
                    f"HUD is missing {name.upper()} (saw: {text!r})"
                )
            values[name] = int(match.group(1))
        return values

    def combo(self) -> int | None:
        """Return the combo streak the HUD is showing, or None when there is none.

        `ScoreDisplay` renders `COMBO xN` only while the streak is 2 or more, so
        a match here is direct evidence that a pop chained off another.
        """
        match = COMBO_PATTERN.search(self.text())
        return int(match.group(1)) if match else None

    def wait_for_hud(self, timeout: float = 20.0) -> dict:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            text = self.text()
            if all(pattern.search(text) for pattern in HUD_PATTERNS.values()):
                return self.hud()
            time.sleep(0.1)
        raise SmokeFailure(
            f"Game screen never rendered its HUD (saw: {self.text()!r})"
        )

    def overlay(self) -> str | None:
        """Return 'lost' / 'won' when a win-or-lose overlay is up.

        The headline is painted on the canvas, so `document.body.innerText`
        never contains it — it survives as the overlay container's aria-label
        ("GAME OVER / Score: n / ..."). The overlay's buttons are the fallback
        signal: `PLAY AGAIN` exists only on the game-over overlay and
        `CONTINUE` only on the level-cleared one.
        """
        labels = self.cdp.evaluate(SEMANTIC_LABELS_JS) or ""
        if "GAME OVER" in labels:
            return "lost"
        if "CLEARED" in labels:
            return "won"
        text = self.text()
        if "PLAY AGAIN" in text:
            return "lost"
        if "CONTINUE" in text:
            return "won"
        return None


# --------------------------------------------------------------------------- #
# The smoke suite
# --------------------------------------------------------------------------- #

# §9 titles, in order. The kind says how the step is proven:
#   asserted    - a state assertion on observable app state
#   behavioural - input is accepted and the shot resolves, but the thing under
#                 test (aim guide, wall bounce) is canvas-only
STEPS = (
    ("Start screen renders; PLAY starts a game", "asserted"),
    ("Aim moves the guide; fire launches the projectile", "behavioural"),
    ("Wall bounce; off-screen shots do not vanish", "behavioural"),
    ("A match-3 pops and scores", "asserted"),
    ("A chain reaction scores again on a consecutive pop", "asserted"),
    ("The wall reaches the cannon line and costs a life", "asserted"),
    ("A life loss costs exactly one life and keeps the level", "asserted"),
    ("Restart resets the session cleanly", "asserted"),
    ("HUD shows score, lives, level and the next queue", "asserted"),
    ("No blocking console errors", "asserted"),
)


class StepResult:
    def __init__(self, number: int, title: str, kind: str) -> None:
        self.number = number
        self.title = title
        self.kind = kind
        self.status = "not run"
        self.detail = ""

    def passed(self, detail: str) -> "StepResult":
        self.status = "PASS"
        self.detail = detail
        return self

    def failed(self, detail: str) -> "StepResult":
        self.status = "FAIL"
        self.detail = detail
        return self


class SmokeSuite:
    def __init__(self, page: Page, max_shots: int, settle: float) -> None:
        self.page = page
        self.cdp = page.cdp
        self.max_shots = max_shots
        self.settle = settle
        self.results: list[StepResult] = []
        self.shots: list[dict] = []
        self._index = 0

    # -- step bookkeeping --------------------------------------------------

    def _next(self) -> StepResult:
        number = self._index + 1
        title, kind = STEPS[self._index]
        result = StepResult(number, title, kind)
        self.results.append(result)
        self._index += 1
        return result

    def run(self) -> list[StepResult]:
        handlers = (
            self.step_start_screen,
            self.step_aim_and_fire,
            self.step_wall_bounce,
            self.step_match3,
            self.step_chains,
            self.step_descent,
            self.step_lives_and_level,
            self.step_restart,
            self.step_hud,
            self.step_console,
        )
        for handler in handlers:
            result = self._next()
            try:
                handler(result)
            except SmokeFailure as error:
                result.failed(str(error))
                break
        return self.results

    # -- geometry and driving ---------------------------------------------

    def _aim_point(self, index: int) -> tuple[float, float]:
        """Sweep the aim across the playfield in a dense, repeating pattern.

        The board is unseeded, so a shot only pops when it happens to land
        adjacent to two same-coloured bubbles. A coarse sweep has blind spots:
        measured over 60 shots, five of nine aim offsets produced every scoring
        shot and the rest produced none, so a board that did not line up with
        those five whiffed indefinitely. Sweeping 17 positions across the width
        targets every column of a nine-column board, and drifting `y` gives each
        column three different approach angles per cycle.
        """
        view = self.page.viewport()
        slots = 17
        offset = -0.48 + 0.96 * (index % slots) / (slots - 1)
        x = view["x"] + view["w"] * (0.5 + offset * 0.76)
        y = view["y"] + view["h"] * (0.30 + 0.05 * ((index // slots) % 3))
        return x, y

    def _fire(self, index: int) -> dict:
        """Fire one shot at sweep position `index`."""
        x, y = self._aim_point(index)
        return self._fire_at(x, y)

    def _fire_at(self, x: float, y: float) -> dict:
        """Fire one shot at a screen point, record what changed, clear overlays.

        A level 1 board reaches the cannon line after three or four shots
        (`descentInterval: 1`, and the opening cluster fills about half the
        rows), so a hunt for a rare event has to span several sessions. Losing a
        life resets the board — and therefore the score — so those shots are
        flagged `reset` and excluded from scoring evidence.
        """
        before = self.page.hud()
        self.cdp.click(x, y)
        time.sleep(self.settle)

        overlay = self.page.overlay()
        after = self.page.hud()  # still readable underneath an overlay
        record = {
            "shot": len(self.shots) + 1,
            "aim": (round(x), round(y)),
            "overlay": overlay,
            "score_before": before["score"],
            "lives_before": before["lives"],
            "level_before": before["level"],
            "score": after["score"],
            "lives": after["lives"],
            "level": after["level"],
            "combo": self.page.combo(),
            "delta": after["score"] - before["score"],
            "life_delta": after["lives"] - before["lives"],
        }
        # A life loss restarts the level, which zeroes the score, so a negative
        # or reset delta says nothing about what the shot scored.
        record["reset"] = overlay is not None or record["life_delta"] < 0
        self.shots.append(record)

        if overlay is not None:
            self._dismiss_overlay(overlay)
        return record

    def _dismiss_overlay(self, overlay: str) -> None:
        """Clear a win/lose overlay so the next hunt can continue."""
        label = "PLAY AGAIN" if overlay == "lost" else "CONTINUE"
        self.page.click_label(label)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if self.page.overlay() is None and self.page.hud()["lives"] > 0:
                return
            time.sleep(0.1)
        raise SmokeFailure(f"{label!r} did not dismiss the {overlay} overlay")

    def _fire_until(self, predicate, budget: int, what: str) -> dict:
        """Fire until `predicate(record)` holds, or fail with a diagnostic."""
        start = len(self.shots)
        for index in range(start, start + budget):
            record = self._fire(index)
            if predicate(record):
                return record
        raise SmokeFailure(
            f"{what} was not observed within {budget} shots "
            f"(per shot: "
            f"{[(r['aim'], r['delta'], r['life_delta'], r['combo'])
               for r in self.shots[start:]]}"
            f")"
        )

    # -- steps -------------------------------------------------------------

    def step_start_screen(self, result: StepResult) -> None:
        text = self.page.text()
        if "BUST A MOVE" not in text:
            raise SmokeFailure(f"Start screen title missing (saw: {text!r})")
        if not self.page.find("PLAY"):
            raise SmokeFailure("Start screen has no PLAY control")
        self.page.click_label("PLAY")
        hud = self.page.wait_for_hud()
        result.passed(
            f"title and PLAY found; the game opened at SCORE {hud['score']}, "
            f"LIVES {hud['lives']}, LEVEL {hud['level']}"
        )

    def step_aim_and_fire(self, result: StepResult) -> None:
        view = self.page.viewport()
        y = view["y"] + view["h"] * 0.45
        for fraction in (0.2, 0.5, 0.8):
            self.cdp.move(view["x"] + view["w"] * fraction, y)
            time.sleep(0.15)
        record = self._fire(0)
        if record["overlay"] is not None:
            raise SmokeFailure(f"One shot ended the session ({record['overlay']})")
        hud = self.page.hud()
        result.passed(
            "pointer moves accepted across the playfield and the shot resolved; "
            f"HUD still live at SCORE {hud['score']}, LIVES {hud['lives']} "
            "(the aim guide is canvas-only — see the module docstring)"
        )

    def step_wall_bounce(self, result: StepResult) -> None:
        view = self.page.viewport()
        # A shallow angle toward the far edge sends the bubble into a side wall.
        self.cdp.click(view["x"] + view["w"] * 0.97, view["y"] + view["h"] * 0.92)
        time.sleep(self.settle)
        overlay = self.page.overlay()
        hud = self.page.hud()  # raises if the shot corrupted the HUD
        if overlay is not None:
            raise SmokeFailure(f"A wall-angled shot ended the session ({overlay})")
        result.passed(
            "a shallow-angle shot at the far edge resolved without stalling the "
            f"session (SCORE {hud['score']}, LIVES {hud['lives']})"
        )

    def step_match3(self, result: StepResult) -> None:
        record = self._fire_until(
            lambda r: not r["reset"] and r["delta"] > 0,
            self.max_shots,
            "a scoring pop",
        )
        result.passed(
            f"SCORE rose {record['score_before']} -> {record['score']} on shot "
            f"{record['shot']}; a match-3 scored"
        )

    def step_chains(self, result: StepResult) -> None:
        """Prove a chain reaction from the `COMBO xN` HUD text.

        A score delta cannot prove a chain: `_popScore` is
        `150 * (groupSize - 1)`, so a five-bubble pop at combo 1 scores exactly
        600 and a four-bubble pop scores 450. Only the combo streak is
        unambiguous, and `ScoreDisplay` publishes it while it is running.

        A chain needs two *consecutive* pops — `combo` increments on a pop and
        resets to 0 on a whiff — so the chance of one is bounded by the pop
        rate, not equal to it. Measured over several runs the wait is
        heavy-tailed (4, 8, 29 and 77 shots before the first chain), so this
        hunt gets a larger budget than the match-3 hunt and a strategy: after a
        shot that scored, fire the same aim again, because the cluster that just
        cleared left a gap in a region that already matched once.

        Detached-cluster drops have no observable surface — their score is
        added to a pop's and the pop's own size is not observable — so that half
        of the release-checklist item stays with the engine unit tests.
        """
        start = len(self.shots)
        repeat: tuple[float, float] | None = None
        for index in range(start, start + CHAIN_SHOT_BUDGET):
            record = self._fire_at(*repeat) if repeat else self._fire(index)
            if not record["reset"] and (record["combo"] or 0) >= 2:
                result.passed(
                    f"the HUD showed COMBO x{record['combo']} on shot "
                    f"{record['shot']}, a {record['delta']}-point single shot "
                    f"from SCORE {record['score_before']} (a detached-cluster "
                    "drop has no observable surface — see the module docstring)"
                )
                return
            scored = not record["reset"] and record["delta"] > 0
            repeat = tuple(record["aim"]) if scored else None
        raise SmokeFailure(
            f"a chain reaction (COMBO x2 or better) was not observed within "
            f"{CHAIN_SHOT_BUDGET} shots (per shot: "
            f"{[(r['aim'], r['delta'], r['life_delta'], r['combo'])
               for r in self.shots[start:]]})"
        )

    def step_descent(self, result: StepResult) -> None:
        record = self._fire_until(
            lambda r: r["life_delta"] < 0,
            self.max_shots,
            "the wall reaching the cannon line",
        )
        result.passed(
            f"a bubble reached the cannon line on shot {record['shot']}: "
            f"LIVES {record['lives_before']} -> {record['lives']} (level 1 "
            "descends on every shot, so descent is what moved it there)"
        )

    def step_lives_and_level(self, result: StepResult) -> None:
        losses = [r for r in self.shots if r["life_delta"] < 0]
        if not losses:
            raise SmokeFailure("No life was ever lost, so LIVES was never proven")
        for record in losses:
            if record["life_delta"] != -1:
                raise SmokeFailure(
                    f"LIVES moved by {record['life_delta']} on shot "
                    f"{record['shot']}; expected exactly -1 per loss"
                )
            if record["level"] != record["level_before"]:
                raise SmokeFailure(
                    f"Losing a life changed LEVEL "
                    f"{record['level_before']} -> {record['level']} on shot "
                    f"{record['shot']}; a life loss restarts the same level"
                )
        hud = self.page.hud()
        if hud["lives"] < 0:
            raise SmokeFailure(f"LIVES went negative: {hud['lives']}")
        if hud["level"] < 1:
            raise SmokeFailure(f"LEVEL is not a real level: {hud['level']}")
        result.passed(
            f"{len(losses)} life loss(es), each exactly -1 and each keeping "
            f"LEVEL {losses[0]['level']} (a level-up on a clear is owned by the "
            "engine and ViewModel tests, which can set the board up)"
        )

    def step_restart(self, result: StepResult) -> None:
        # Play one shot first so the reset has something to undo.
        self._fire(len(self.shots))
        # A win that lands just after `_fire` reads the overlay would send
        # `restart()` down its level-up branch and fail the assertions below on
        # a correct app, so give a late overlay a moment to show up first.
        deadline = time.monotonic() + 1.2
        while time.monotonic() < deadline:
            late = self.page.overlay()
            if late is not None:
                self._dismiss_overlay(late)
                break
            time.sleep(0.2)
        before = self.page.hud()
        label = self.page.click_label("Restart level", "PLAY AGAIN", "CONTINUE")
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if self.page.overlay() is not None:
                time.sleep(0.1)
                continue
            hud = self.page.hud()
            if hud["score"] == 0 and hud["level"] == 1 and hud["lives"] == 3:
                result.passed(
                    f"{label!r} reset SCORE {before['score']} -> 0, "
                    f"LEVEL {before['level']} -> 1, LIVES {before['lives']} -> 3"
                )
                return
            time.sleep(0.1)
        raise SmokeFailure(
            f"Restart did not reset the session (HUD: {self.page.hud()})"
        )

    def step_hud(self, result: StepResult) -> None:
        hud = self.page.hud()
        text = self.page.text()
        if "NEXT" not in text:
            raise SmokeFailure("The next-colour queue is missing from the HUD")
        for name in ("score", "lives", "level"):
            if not isinstance(hud[name], int):
                raise SmokeFailure(f"HUD {name} is not an integer: {hud[name]!r}")
        # The session was just restarted, so no pop streak can be running and
        # `ScoreDisplay` must not still be rendering a combo.
        combo = self.page.combo()
        if combo is not None:
            raise SmokeFailure(
                f"A fresh session is still showing COMBO x{combo}: {text!r}"
            )
        result.passed(
            f"SCORE {hud['score']}, LIVES {hud['lives']}, LEVEL {hud['level']} "
            "and the next-colour queue all present, with no stale combo streak"
        )

    def step_console(self, result: StepResult) -> None:
        # Drain anything still in flight so an error logged by the last shot is
        # counted rather than missed.
        self.cdp.pump_events(0.3)
        if self.cdp.console_errors:
            joined = "\n    ".join(self.cdp.console_errors[:10])
            raise SmokeFailure(f"Console errors were logged:\n    {joined}")
        result.passed("no console errors and no uncaught exceptions")

    # -- artifacts ---------------------------------------------------------

    def capture_artifacts(self, reason: str, artifact_dir: str) -> list[str]:
        """Write what we can about a failure. Never raises.

        This runs on the failure path, so anything that escapes it would mask
        the original failure and leave the run with no diagnostics at all.
        `console.log` is written first because it is the cheapest and the most
        useful; the screenshot and the trace are best-effort after it.
        """
        try:
            os.makedirs(artifact_dir, exist_ok=True)
        except OSError as error:
            log(f"  (could not create {artifact_dir}: {error})")
            return []
        written: list[str] = []

        console_path = os.path.join(artifact_dir, "console.log")
        try:
            try:
                page_text = self.page.text()
            except Exception as error:  # noqa: BLE001 - diagnostics only
                page_text = f"(unavailable: {error})"
            with open(console_path, "w", encoding="utf-8") as handle:
                handle.write(f"# smoke failure: {reason}\n")
                handle.write(f"# page text: {page_text}\n\n")
                handle.write("# shots:\n")
                for record in self.shots:
                    handle.write(f"#   {record}\n")
                handle.write("\n# console:\n")
                for line in self.cdp.console_errors or ["(no console errors)"]:
                    handle.write(line + "\n")
            written.append(console_path)
        except OSError as error:
            log(f"  (could not write console.log: {error})")

        screenshot_path = os.path.join(artifact_dir, "screenshot.png")
        try:
            with open(screenshot_path, "wb") as handle:
                handle.write(self.cdp.live_screenshot())
            written.append(screenshot_path)
        except Exception as error:  # noqa: BLE001 - diagnostics only
            log(f"  (could not capture a screenshot: {error})")

        try:
            events = self.cdp.stop_trace()
            trace_path = os.path.join(artifact_dir, "trace.json")
            with open(trace_path, "w", encoding="utf-8") as handle:
                json.dump({"traceEvents": events}, handle)
            written.append(trace_path)
        except Exception as error:  # noqa: BLE001 - the trace is best-effort
            log(f"  (could not capture a trace: {error})")

        return written


# --------------------------------------------------------------------------- #
# Minimal RFC 6455 WebSocket client (stdlib only)
# --------------------------------------------------------------------------- #


class WebSocket:
    """Just enough of RFC 6455 to talk to the Chrome DevTools Protocol."""

    def __init__(self, host: str, port: int, path: str, timeout: float = 30.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.settimeout(timeout)
        self._buffer = b""
        self._handshake(host, port, path)

    def _handshake(self, host: str, port: int, path: str) -> None:
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        # No Origin header: Chrome only rejects origins it was not told to
        # allow, so omitting it keeps this client dependency-free.
        request = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self.sock.sendall(request.encode("ascii"))
        while b"\r\n\r\n" not in self._buffer:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise SmokeFailure("WebSocket handshake: connection closed")
            self._buffer += chunk
        head, _, rest = self._buffer.partition(b"\r\n\r\n")
        self._buffer = rest
        status_line = head.split(b"\r\n", 1)[0].decode("latin-1")
        if "101" not in status_line:
            raise SmokeFailure(f"WebSocket handshake failed: {status_line}")

    def _recv_exact(self, count: int) -> bytes:
        while len(self._buffer) < count:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise SmokeFailure("WebSocket closed unexpectedly")
            self._buffer += chunk
        taken, self._buffer = self._buffer[:count], self._buffer[count:]
        return taken

    def send_text(self, text: str) -> None:
        payload = text.encode("utf-8")
        frame = bytearray([0x81])  # FIN + text opcode
        length = len(payload)
        if length < 126:
            frame.append(0x80 | length)
        elif length < 65536:
            frame.append(0x80 | 126)
            frame += struct.pack("!H", length)
        else:
            frame.append(0x80 | 127)
            frame += struct.pack("!Q", length)
        mask = os.urandom(4)
        frame += mask
        frame += bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.sock.sendall(bytes(frame))

    def _send_control(self, opcode: int, payload: bytes = b"") -> None:
        mask = os.urandom(4)
        frame = bytes([0x80 | opcode, 0x80 | len(payload)]) + mask
        frame += bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.sock.sendall(frame)

    def recv_text(self) -> str:
        assembled = b""
        while True:
            first, second = self._recv_exact(2)
            final = first & 0x80
            opcode = first & 0x0F
            masked = second & 0x80
            length = second & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            mask = self._recv_exact(4) if masked else None
            data = self._recv_exact(length) if length else b""
            if mask:
                data = bytes(byte ^ mask[index % 4] for index, byte in enumerate(data))
            if opcode == 0x9:  # ping
                self._send_control(0xA, data)
                continue
            if opcode == 0xA:  # pong
                continue
            if opcode == 0x8:  # close
                raise SmokeFailure("WebSocket closed by the browser")
            assembled += data
            if final:
                return assembled.decode("utf-8", errors="replace")

    def close(self) -> None:
        try:
            self._send_control(0x8)
        except OSError:
            pass
        try:
            self.sock.close()
        except OSError:
            pass


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #


def build_artifact(repo_root: str, skip_build: bool) -> str:
    build_web = os.path.join(repo_root, "build", "web")
    index = os.path.join(build_web, "index.html")
    if skip_build:
        if not os.path.exists(index):
            raise SmokeFailure(
                "--no-build was given but build/web/index.html does not exist"
            )
        return build_web
    log("Building the production web bundle ...")
    started = time.monotonic()
    try:
        result = subprocess.run(
            ["flutter", "build", "web", "--release", "--base-href",
             f"/{BASE_PATH}/"],
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=BUILD_TIMEOUT_S,
        )
    except FileNotFoundError as error:
        raise SmokeFailure(
            "the `flutter` executable was not found on PATH; install the "
            "Flutter SDK or run with --no-build against an existing build/web"
        ) from error
    except subprocess.TimeoutExpired as error:
        raise SmokeFailure(
            f"flutter build web did not finish within {BUILD_TIMEOUT_S}s"
        ) from error
    if result.returncode != 0:
        raise SmokeFailure(f"flutter build web failed:\n{result.stdout[-3000:]}")
    log(f"  built in {time.monotonic() - started:.1f}s")
    return build_web


def stage_artifact(build_web: str, staging_root: str) -> str:
    """Copy build/web to <staging>/bust_a_move_clone so the base href resolves."""
    shutil.copytree(build_web, os.path.join(staging_root, BASE_PATH),
                    dirs_exist_ok=True)
    return staging_root


def _wrap(text: str, width: int) -> list[str]:
    words, lines, current = text.split(), [], ""
    for word in words:
        if current and len(current) + 1 + len(word) > width:
            lines.append(current)
            current = word
        else:
            current = f"{current} {word}".strip()
    if current:
        lines.append(current)
    return lines


def report(suite: SmokeSuite, elapsed: float, max_shots: int) -> None:
    log()
    log(f"{'STEP':<5}{'KIND':<13}{'RESULT':<9}WHAT")
    log("-" * 96)
    for result in suite.results:
        log(f"{result.number:<5}{result.kind:<13}{result.status:<9}{result.title}")
        if result.detail:
            for line in _wrap(result.detail, 70):
                log(f"{'':<27}{line}")
    for number in range(len(suite.results) + 1, len(STEPS) + 1):
        title, kind = STEPS[number - 1]
        log(f"{number:<5}{kind:<13}{'not run':<9}{title}")
    log("-" * 96)
    log(f"wall clock: {elapsed:.1f}s   shots fired: {len(suite.shots)}   "
        f"shot budgets: {max_shots} (chain hunt {CHAIN_SHOT_BUDGET})")


def run(args: argparse.Namespace) -> int:
    repo_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    artifact_dir = os.path.join(repo_root, "build", "smoke-artifacts", stamp)

    build_web = build_artifact(repo_root, args.no_build)
    chrome_binary = find_chrome(args.chrome)
    # The §14 budget covers the suite, not the compile that precedes it.
    started = time.monotonic()

    with tempfile.TemporaryDirectory(prefix="bam-smoke-") as workspace:
        staging = os.path.join(workspace, "www")
        os.makedirs(staging)
        stage_artifact(build_web, staging)
        profile = os.path.join(workspace, "chrome-profile")
        os.makedirs(profile)

        with StaticServer(staging) as server, Chrome(
            chrome_binary, profile, args.width, args.height, not args.headed
        ) as chrome:
            cdp: Cdp | None = None
            suite: SmokeSuite | None = None
            try:
                cdp = Cdp(chrome.page_websocket_url())
                page = Page(cdp)
                suite = SmokeSuite(page, args.max_shots, args.settle)
                cdp.send("Page.enable")
                cdp.send("Runtime.enable")
                cdp.send("Log.enable")
                cdp.send("Page.navigate", {"url": server.base_url})
                page.wait_for_app()
                page.enable_semantics()
                cdp.start_screencast()
                cdp.start_trace()
                results = suite.run()
            except (SmokeFailure, OSError) as error:
                elapsed = time.monotonic() - started
                if suite is not None:
                    report(suite, elapsed, args.max_shots)
                log()
                log(f"FAIL — {error}")
                if suite is None:
                    log("No artifacts: the browser session never came up.")
                else:
                    log("Artifacts:")
                    for path in suite.capture_artifacts(
                        str(error), artifact_dir
                    ):
                        log(f"  {path}")
                return 1
            finally:
                if cdp is not None:
                    cdp.close()

            elapsed = time.monotonic() - started
            report(suite, elapsed, args.max_shots)
            failures = [r for r in results if r.status != "PASS"]
            if failures:
                log()
                log(f"FAIL — {failures[0].number}. {failures[0].title}: "
                    f"{failures[0].detail}")
                log("Artifacts:")
                for path in suite.capture_artifacts(
                    failures[0].detail, artifact_dir
                ):
                    log(f"  {path}")
                return 1
            if elapsed > TIME_BUDGET_S:
                log()
                log(f"FAIL — the suite took {elapsed:.1f}s, over the "
                    f"{TIME_BUDGET_S:.0f}s budget in test-strategy.md §14")
                return 1

            log()
            log(f"PASS — {len(results)}/{len(STEPS)} steps in {elapsed:.1f}s "
                f"({len(suite.shots)} shots fired)")
            return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Release smoke suite against the built web artifact."
    )
    parser.add_argument("--no-build", action="store_true",
                        help="use the existing build/web instead of rebuilding")
    parser.add_argument("--headed", action="store_true",
                        help="run Chrome with a visible window (debugging)")
    parser.add_argument("--chrome", default=None,
                        help="path to a Chrome/Chromium binary")
    parser.add_argument("--max-shots", type=int, default=DEFAULT_MAX_SHOTS,
                        help="shots to fire while hunting for a match-3")
    parser.add_argument("--settle", type=float, default=DEFAULT_SETTLE_S,
                        help="seconds to wait after a shot for it to resolve")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=900)
    args = parser.parse_args(argv)

    try:
        return run(args)
    except (SmokeFailure, OSError) as error:
        log(f"FAIL — {error}")
        return 1
    except KeyboardInterrupt:
        log("interrupted")
        return 130


if __name__ == "__main__":
    sys.exit(main())
