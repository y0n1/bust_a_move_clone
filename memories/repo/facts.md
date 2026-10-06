# Repo facts — Bust-A-Move Clone

**Last updated:** 2026-10-06

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
  main.dart            — MaterialApp entry point
  game/
    model.dart         — BubbleColor, Bubble, Projectile, GameState, GameStatus
    engine.dart        — Engine: hex-grid, shooting, collision, match-3, chain reactions, cluster drop, wall descent
  ui/
    game_screen.dart   — CustomPainter canvas, pointer input, 60Hz ticker, HUD
test/
  engine_test.dart     — Headless engine tests
  descent_test.dart    — Headless engine tests
docs/
  bust_a_move_spec.md  — Original game design spec (immutable source)
```

## Verified practices

- Domain layer (`lib/game/`) is pure Dart — no Flutter imports. Tests run headlessly.
- Engine returns new `GameState` snapshots per mutation; UI replaces wholesale.
- `math.Random` seeded for deterministic tests.
- Board geometry: odd rows offset right by half a bubble. Row 0 has `cols` cells; odd rows have `cols - 1`.
- Cannon at `(cols / 2, rows + 1)` in board-space.
- `Engine.centerOf(row, col)` returns cell center in board-space.
- `Engine.neighborsOf(row, col)` returns 6 hex-neighbors (handles even/odd offset).

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
