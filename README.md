# Bust A Move (Flutter web clone)

A Flutter web clone of the classic 1994 arcade bubble-shooter *Bust‑A‑Move*
(a.k.a. *Puzzle Bobble*). Aim the cannon, match 3+ same-colored bubbles to
pop, clear the board before the wall descends to the cannon line.

## Getting started

Prerequisites:

- [Flutter](https://docs.flutter.dev/get-started/install) (stable) with
  Dart ≥ 3.13.1 and the **Web** platform enabled
  (`flutter doctor` should show `Chrome` as a web target).

```bash
# 1. Install dependencies
flutter pub get

# 2. Run the web app in debug mode
flutter run -d chrome

# 3. (Optional) Run the unit tests
flutter test test/engine_test.dart

# 4. (Optional) Build a release bundle for web
flutter build web --release
# → output in build/web/; serve it with `python3 -m http.server` or any
#   static file server.
```

## Project layout

```
lib/
  main.dart           # App entry point + start screen
  game/
    model.dart        # Pure-Dart data model (Bubble, Projectile, GameState)
    engine.dart       # Pure-Dart game engine (hex grid, match, drop, descent)
  ui/
    game_screen.dart  # Canvas rendering + input + HUD
test/
  engine_test.dart    # Headless unit tests for the engine
docs/
  bust_a_move_spec.md # High-level game spec
```

The **domain layer** (`lib/game/`) has no Flutter imports, so it can be unit
tested on plain Dart and ported to other platforms later. The **UI layer**
(`lib/ui/`) renders a `GameState` snapshot and feeds pointer events back
into the engine.

## How to play

- Move the mouse (or drag your finger) to aim the cannon.
- Click / tap to fire.
- Match 3 or more same-colored bubbles to pop them.
- Detached clusters fall off the board.
- The wall descends one row after every shot — clear the board before it
  reaches the cannon line!
