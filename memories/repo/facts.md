# Repo facts — Bust-A-Move Clone

**Last updated:** 2026-10-23

## Build commands

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Static analysis | `flutter analyze` |
| Format | `flutter format .` |
| Lint fix | `dart fix --apply` |
| Run single test | `flutter test path/to/file_test.dart` |
| Run web (debug) | `flutter run -d chrome` |
| Build web release | `flutter build web --release` |
| Clean | `flutter clean` |

## Project structure

```
lib/
  main.dart            — MaterialApp entry point → StartScreen
  game/
    model.dart         — BubbleColor, Bubble, Projectile, GameState, GameStatus
    engine.dart        — Engine: hex-grid, shooting, collision, match-3, chain reactions, cluster drop, wall descent
  gameplay/
    viewmodel/game_viewmodel.dart  — GameViewModel (ChangeNotifier): Engine, GameState, Ticker, aim/fire/restart, juice FX, layout
    ui/game_screen.dart            — Thin View: listens to ViewModel, pointer input
    ui/hud/                        — ScoreDisplay, LevelDisplay
    ui/renderer/bubble_renderer.dart — GamePainter + ScorePopup/Particle/ParticleBurst
  start_screen/
    start_screen.dart              — Title / PLAY / instructions
    viewmodel/start_screen_viewmodel.dart — createGame() factory
test/
  engine_test.dart     — Headless engine tests
  descent_test.dart    — Headless engine tests
  gameplay/viewmodel/game_viewmodel_test.dart
  start_screen/viewmodel/start_screen_viewmodel_test.dart
docs/
  bust_a_move_spec.md  — Original game design spec (immutable source)
  architecture.md      — MVVM architecture reference
```

## Verified practices

- Domain layer (`lib/game/`) is pure Dart — no Flutter imports. Tests run headlessly.
- Engine returns new `GameState` snapshots per mutation; UI replaces wholesale.
- `math.Random` seeded for deterministic tests.
- MVVM: Views never touch `Engine`. ViewModels extend `ChangeNotifier`, own the `Ticker`, and call the engine.
- A plain (non-widget) class has no `TickerProvider` — construct `Ticker(_onTick)` directly.
- Folder name is `viewmodel/` (singular, no underscore) in both features.
- Board geometry: odd rows offset right by half a bubble. Row 0 has `cols` cells; odd rows have `cols - 1`.
- Cannon at `(cols / 2, rows + 1)` in board-space.
- `Engine.centerOf(row, col)` returns cell center in board-space.
- `Engine.neighborsOf(row, col)` returns 6 hex-neighbors (handles even/odd offset).

## Production & quality baseline (2026-10-23)

- **Production:** https://y0n1.github.io/bust_a_move_clone/ — GitHub Pages, deployed from `main`.
- **Deploy workflow:** `.github/workflows/deploy-pages.yml`; **CI:** `.github/workflows/ci.yml`.
- **Build:** `flutter build web --release --base-href /bust_a_move_clone/`.
- **Last verified deploy:** run 39882358617, commit `4b5d3fe`, version 1.0.0+1.
- **Quality baseline:** `flutter analyze --fatal-infos` clean; 45 tests pass; production build succeeds.
- **Sizes:** `main.dart.js` 0.54 MB gzip; `canvaskit.wasm` 2.79 MB gzip; `build/web` 40 MB.
- **Gaps:** no `v1.0.0` tag; CI does not build web on PR; Flutter version floats on `stable`;
  no automated post-deploy smoke; no uptime monitoring; no cross-browser/a11y/perf evidence;
  `develop` branch not yet created on the remote.
- **Artifacts:** `docs/ops/deployment.md`, `docs/ops/deployment-log.md`,
  `docs/quality/test-strategy.md`, `docs/quality/release-checklist.md`,
  `docs/quality/reports/2026-10-23-v1.0.0-baseline.md`, `docs/status/2026-10-23-kickoff.md`.
- **Team:** 7 roles / 7 agents in `.github/agents/` (PM, UX, Engine, Flutter, Multiplayer, QE, DevOps).
  The PM covers product **and** delivery; there is no separate project manager.
- **Branching:** Gitflow + Conventional Commits — see `docs/decisions/0001-gitflow-and-conventional-commits.md`.
  Task branches cut from `develop`, PRs target `develop`; only `release/*` and
  `hotfix/*` target `main`. CI (`.github/workflows/ci.yml`, job `analyze-test`)
  runs on PRs into `main`/`develop` and on pushes to `develop`.

## Previous session fixes (2026-10-06)

- **Descent logic inverted** — fixed in `lib/game/engine.dart`:
  - `startLevel()` fills only top half of board (`rows / 2` rows)
  - `_applyDescent` shifts bubbles **down** (`b.row + 1`) instead of up
  - `_dropDetached` flood-fills from topmost occupied row
  - `_computeStatus` loses only at row `rows` (cannon line)
- Regression tests in `test/descent_test.dart` (6 tests)
- **Needs in-browser verification** — first task for the next session

## Known loose ends

- **Death line mismatch**: UI draws death line at `engine.rows - 1`; engine loses at row `rows`. Consider aligning.
- **`_nearestFreeCell`** bounds-checks against `rows`; after descent bubbles can occupy row `rows` — BFS may reject valid cells.
- **`_snapToHex`** scans `rows + 8` rows — plenty for now, revisit if board grows.
- **Lives / level** still inert (issues #2, #3).
- **No sound** — spec mentions audio; not implemented.

## Open issues (Kanban)

| # | Title | Status |
|---|-------|--------|
| #1 | One-shot game over: descent logic inverted | Fix landed, needs in-browser verification |
| #2 | Lives never decrement | Not started |
| #3 | Level progression: difficulty scaling | Not started |
| #4 | Juice & feel: particles, screen shake, score popups | Not started |
| #5 | Scoring: combo multipliers and HUD popups | Not started |
