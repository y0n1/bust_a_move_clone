# Bust-A-Move Clone — Handover Summary

*Last updated: 2026-10-06 ~15:20 (Asia/Jerusalem)*

## 1. Project status

A Flutter web clone of the 1994 arcade bubble-shooter. Pure-Dart engine + Flutter UI. The project was **unplayable** when work began: every shot instantly triggered `GAME OVER` with score 0.

### What's been done

1. **Feedback loop established** — the agent can now "play" the game headlessly:
   - Flutter SDK at `/home/y0n1/.flutter/bin/flutter` (3.47.1) — two telemetry-file permission issues were fixed (`~/.config/flutter/tool_state`, `~/.dart-tool/dart-flutter-telemetry.config`)
   - Release web bundle built (`flutter build web --release`) and served on `http://127.0.0.1:8400` (Python `http.server` background job)
   - Headed Chrome on display `:1` with CDP on port 9322 (user can watch the browser)
   - CDP harness: `tools/cdp.py` + `.playback-venv/` (Python + `websockets`) — screenshots, mouse events at pixel coords, JS eval
   - Verified: start screen → PLAY → aim → fire → observe result

2. **Bug #1 diagnosed and fixed** (descent logic inverted):
   - `lib/game/engine.dart`:
     - `startLevel()` now fills only the **top half** of the board (`rows / 2` rows) so the cluster has room to descend
     - `_applyDescent` now shifts bubbles **down** (`b.row + 1`) instead of up
     - `_dropDetached` now flood-fills from the **topmost occupied row** (correct "attached to the wall" semantics)
     - `_computeStatus` loses only when a bubble reaches the cannon line (row `rows`)
   - Regression tests added in `test/descent_test.dart` (6 tests covering one-shot survival, descent, top-row retention, detached-cluster fall, scoring)
   - **Not yet verified in-browser** — that's the first task for the new chat

3. **Project management set up on GitHub**:
   - Private repo: [y0n1/bust_a_move_clone](https://github.com/y0n1/bust_a_move_clone)
   - Kanban project board created (user did this in the UI; 5 issues auto-moved to Backlog)
   - Issue templates: `.github/ISSUE_TEMPLATE/{bug,feature,config}.md`
   - Labels: `bug`, `enhancement` (GitHub defaults, already in use)
   - All source files pushed (text via API, then user aligned local `main` with upstream via SSH; user's key is now on the GitHub account)

### Open tickets

| # | Type | Title | Notes |
|---|------|-------|-------|
| [#1](https://github.com/y0n1/bust_a_move_clone/issues/1) | Bug | One-shot game over: descent logic is inverted | Fix landed in `main`, **needs in-browser verification** |
| [#2](https://github.com/y0n1/bust_a_move_clone/issues/2) | Bug | Lives never decrement | `lives` field is never modified; needs a "continue" flow |
| [#3](https://github.com/y0n1/bust_a_move_clone/issues/3) | FR | Level progression: difficulty scaling | `level` always 1; no color/row/descent-rate scaling |
| [#4](https://github.com/y0n1/bust_a_move_clone/issues/4) | FR | Juice & feel: particles, screen shake, score popups | Purely visual; no logic changes |
| [#5](https://github.com/y0n1/bust_a_move_clone/issues/5) | FR | Scoring: combo multipliers and HUD popups | Combo counter, score multiplier, progress bar |

## 2. Immediate next step (Bug #1 verification)

1. Rebuild: `cd /home/y0n1/Projects/bust_a_move_clone && bash /home/y0n1/.flutter/bin/flutter build web --release`
2. Restart the static server if it died: `cd build/web && python3 -m http.server 8400`
3. Restart Chrome if needed: `DISPLAY=:1 google-chrome --remote-debugging-port=9322 --user-data-dir=/tmp/bam-chrome --window-size=800,900 --no-sandbox --disable-dev-shm-usage about:blank`
4. Navigate to `http://127.0.0.1:8400/index.html` via CDP
5. Click PLAY (center of start screen, ~384,400 in an 800×900 viewport)
6. Fire 3–5 shots at different angles; verify:
   - No `GAME OVER` after the first shot
   - The cluster visibly descends one row per shot
   - Score increases when a match pops
   - Top row still has bubbles after descent
7. Screenshot each state; attach to issue #1
8. Run the test suite: `bash /home/y0n1/.flutter/bin/flutter test test/` (both `engine_test.dart` and `descent_test.dart` should pass)
9. Update issue #1 status (move to In Review / Done on the Kanban)

## 3. Environment cheat-sheet

| Item | Value |
|------|-------|
| Project root | `/home/y0n1/Projects/bust_a_move_clone` |
| Flutter | `/home/y0n1/.flutter/bin/flutter` (3.47.1, stable) |
| Dart | 3.13.1 |
| Chrome | `/usr/bin/google-chrome` (154), headed on `DISPLAY=:1` |
| CDP port | `9322` |
| Web server | `http://127.0.0.1:8400` (serving `build/web/`) |
| CDP harness | `tools/cdp.py` + `.playback-venv/bin/python` |
| GitHub repo | `git@github.com:y0n1/bust_a_move_clone.git` (SSH, user's key) |
| Kanban | https://github.com/y0n1/bust_a_move_clone/projects (5 issues in Backlog) |

### CDP harness quick reference

```python
import sys
sys.path.insert(0, "tools")
from cdp import Cdp
cdp = Cdp("ws://127.0.0.1:9322/devtools/page/<PAGE_ID>")
cdp.set_viewport(800, 900)
cdp.send("Page.navigate", {"url": "http://127.0.0.1:8400/index.html"})
cdp.mouse_move(200, 300)   # aim
cdp.click(200, 300)        # fire
cdp.screenshot("/tmp/shot.png")
cdp.evaluate("document.title")  # JS eval
```

Get the page WS URL:
```bash
curl -s http://127.0.0.1:9322/json/list | python3 -c "import json,sys; ts=json.load(sys.stdin); print([t for t in ts if t['type']=='page'][0]['webSocketDebuggerUrl'])"
```

## 4. Key files

- `lib/game/engine.dart` — the fixed engine (descent, drop, status)
- `lib/game/model.dart` — `GameState`, `Bubble`, `Projectile` (immutable snapshots)
- `lib/ui/game_screen.dart` — canvas rendering + input + HUD (death line is still drawn at `rows - 1`; may need updating to match the new cannon-line semantics)
- `test/engine_test.dart` — original unit tests (all passing)
- `test/descent_test.dart` — new regression tests (added this session)
- `tools/cdp.py` — CDP harness
- `.github/ISSUE_TEMPLATE/` — bug / feature / config templates

## 5. Known loose ends / gotchas

- **Death line in the UI** (`game_screen.dart` line ~217) is drawn at `engine.rows - 1`; the engine now loses at row `rows`. Consider moving the visual line to match.
- **`_nearestFreeCell`** bounds-checks against `rows`, but after descent bubbles can occupy row `rows` — the BFS may reject valid cells. Watch for this during play.
- **`_snapToHex`** scans `rows + 8` rows, which is plenty for now but worth revisiting if the board grows.
- **Lives / level** are still inert (issues #2, #3).
- **No sound** — the spec mentions audio; not implemented.
- **`web/icons/Icon-maskable-512.png`** — confirm it's in the pushed history (the last API push was interrupted; the user re-aligned `main` via SSH, so it should be there).
- **`.playback-venv/`** is a local artifact (Python venv); add to `.gitignore` if it's not already covered.
- **`outputs/` and `current_session_context/`** in the project root are agent workspace artifacts; not part of the game.

## 6. Conventions (from CLAUDE.md)

- Keep `lib/game/` free of Flutter imports (pure Dart, testable headlessly)
- Engine returns a fresh `GameState` per mutation (no in-place mutation)
- All randomness via `math.Random` (seedable, deterministic)
- Common commands: `flutter pub get`, `flutter analyze`, `flutter test test/<file>`, `flutter run -d chrome`, `flutter build web --release`
