# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common commands

| Goal | Command |
|------|---------|
| Install dependencies | `flutter pub get` |
| Run static analysis & formatting | `flutter analyze`  <br> `flutter format .` |
| Lint fixes (Dart) | `dart fix --apply` |
| Execute a single test file | `flutter test path/to/file_test.dart` |
| Run the web app in debug mode | `flutter run -d chrome` |
| Build release for web | `flutter build web --release` |
| Clean build artifacts | `flutter clean` |

## High‑level architecture

- **Entry point**: `lib/main.dart` sets up a `MaterialApp` and launches the start screen.
- **Game domain (pure Dart, no Flutter)**:
  - `lib/game/model.dart` — `BubbleColor`, `Bubble`, `Projectile`, `GameState`, `GameStatus`. The UI renders from `GameState`; the engine returns a fresh `GameState` for every mutation.
  - `lib/game/engine.dart` — `Engine`: hex-grid geometry, board generation, aiming, shooting, collision, 3+ match pop, chain reactions, detached-cluster drop, wall descent, scoring, win/lose. Deterministic given a fixed `math.Random`.
- **UI (Flutter widgets)**:
  - `lib/ui/game_screen.dart` — `GameScreen`: a `CustomPainter` canvas that renders `GameState`, captures pointer input (aim + fire), drives the engine via a 60 Hz `Ticker`, and draws the HUD (score, lives, level, next-colors queue, remaining bubbles).
- **State management**: the engine owns all game state. `GameScreen` holds a `GameState` field and replaces it wholesale on every tick / shot. No Riverpod / Provider yet; add only when the app grows.
- **Assets**: sprite sheets, sounds, and fonts will be placed under `assets/` and declared in `pubspec.yaml` (the `flutter:` section) when the retro-art pass lands.
- **Testing**: `test/engine_test.dart` covers the core match / drop / descent logic headlessly (no Flutter imports).

### Board geometry cheat-sheet

- Rows are stacked vertically; odd rows are offset right by half a bubble (hex packing).
- Row 0 has `cols` cells; odd rows have `cols - 1`.
- Board-space is in "bubble diameters": `(0, 0)` is the top-left corner; y grows down.
- `Engine.centerOf(row, col)` returns the center of the cell at `(row, col)` in board-space.
- The cannon sits at `(cols / 2, rows + 1.2)`.
- `Engine.neighborsOf(row, col)` returns the 6 hex-neighbors of a cell (handles even/odd row offset).

## Conventions

- Keep the domain layer (`lib/game/`) free of Flutter imports so unit tests can run on plain Dart and so the engine can be ported to other platforms later.
- Prefer immutable snapshots (`GameState`) over mutable in-place updates; the engine returns a new `GameState` for every mutation.
- Use `math.Random` for all randomness so tests can be seeded and deterministic.
