# Architecture — Bust-A-Move Clone

Flutter app architecture: MVVM, a pure-Dart game domain, and feature folders.

## Guiding Principles

| Principle | Application |
| ----------- | ------------- |
| **Unidirectional Data Flow** | Views forward input to ViewModels; ViewModels call the engine and notify Views when state changes. |
| **Separation of Concerns** | Each layer owns its data and logic; layers communicate through well-defined boundaries. |
| **MVVM Pattern** | View (Flutter widgets) → ViewModel (state + business logic) → Model (domain entities). |
| **Feature-Based Folders** | Group by feature, not by technology. Each feature owns its UI, logic, and tests. |
| **Immutable State** | `GameState` snapshots; engine returns new instances. No in-place mutations. |
| **Pure Dart Domain** | Domain layer (`lib/game/`) has zero Flutter dependencies. Fully testable headlessly. |

## Layering

```text
StartScreen / GameScreen
          ↓ input
StartScreenViewModel / GameViewModel
          ↓ game actions and state
     Engine + GameState
          ↓ updated state
       ViewModels → Views
```

### Layer Responsibilities

| Layer | Contents | Dependencies |
| ------- | ---------- | ------------- |
| **Domain** (`lib/game/`) | `model.dart` (game state and entities), `engine.dart` (game rules, grid, collision, and scoring) | None — pure Dart |
| **ViewModels** (`lib/gameplay/viewmodel/`, `lib/start_screen/viewmodel/`) | Game state coordination, ticker, aiming/firing, restart, and game creation | Domain; Flutter foundation for `ChangeNotifier` |
| **UI** (`lib/gameplay/ui/`, `lib/start_screen/`) | Game and start-screen widgets, HUD, renderer, and input forwarding | ViewModels and Flutter |

## Board Geometry

- Rows stack vertically; odd rows are offset right by half a bubble.
- Row 0 has `cols` cells; odd rows have `cols - 1`.
- Board-space is measured in bubble diameters: `(0, 0)` is the top-left, and
  y increases downward.
- The cannon is at `(cols / 2, rows + 1)` in board-space.
- `Engine.centerOf(row, col)` returns a cell's center in board-space.
- `Engine.neighborsOf(row, col)` returns the six hex-neighbors, accounting for
  even and odd row offsets.

## Development Conventions

- Keep `lib/game/` pure Dart, without Flutter imports, so engine tests run
  headlessly.
- Treat engine results as immutable `GameState` snapshots; presentation code
  replaces the current snapshot instead of mutating it.
- Inject `math.Random` into the engine. Use seeded instances in tests for
  reproducible game behavior.
- Views render state and forward input; they do not call `Engine`. ViewModels
  extend `ChangeNotifier`, own the ticker, and coordinate engine calls.
- Keep assets such as sprites, sounds, and fonts under `assets/` and declare
  them in `pubspec.yaml`.

## Naming Conventions

| Layer | Suffix | Example |
| ------- | -------- | --------- |
| ViewModels | `ViewModel` | `GameViewModel` |
| Domain entities | POCOs | `GameState`, `Bubble` |
| UI widgets | Semantic name | `ScoreDisplay`, `LevelDisplay` |
| Renderers | `Painter` | `GamePainter` |
| Services | `Service` (future) | `SaveService` |

## State Management

**`ChangeNotifier` ViewModels** (no external state-management package).

Rationale:

- Views forward input and render ViewModel state; ViewModels own presentation
  state and call the engine.
- The game rules stay in pure Dart and remain headlessly testable.

## Code Map

| Subsystem | Location | Responsibility |
| ----------- | ---------- | ---------------- |
| Entry point | `lib/main.dart` | Creates the `MaterialApp` and opens the start screen |
| Game domain | `lib/game/model.dart`, `lib/game/engine.dart` | Game state and pure-Dart game rules |
| Start screen | `lib/start_screen/start_screen.dart`, `lib/start_screen/viewmodel/start_screen_viewmodel.dart` | Start screen UI and game creation |
| Game ViewModel | `lib/gameplay/viewmodel/game_viewmodel.dart` | Engine/state coordination, ticker, aiming, firing, restart, effects, and layout |
| Game View | `lib/gameplay/ui/game_screen.dart` | Pointer input, game painting, HUD, and status overlay |
| Renderer | `lib/gameplay/ui/renderer/bubble_renderer.dart` | `GamePainter`, score popups, particles, and bursts |
| HUD | `lib/gameplay/ui/hud/` | Score and level displays |
| Tests | `test/engine_test.dart`, `test/descent_test.dart`, `test/engine_determinism_test.dart`, `test/gameplay/viewmodel/`, `test/start_screen/viewmodel/`, `test/start_screen_test.dart`, `test/web_assets_test.dart` | Engine, ViewModel, start-screen, and web asset coverage |

## Folder Structure

```text
lib/
├── main.dart
├── game/
│   ├── model.dart
│   └── engine.dart
├── start_screen/
│   ├── start_screen.dart
│   └── viewmodel/
│       └── start_screen_viewmodel.dart
└── gameplay/
    ├── viewmodel/
    │   └── game_viewmodel.dart
    └── ui/
        ├── game_screen.dart
        ├── hud/
        │   ├── level_display.dart
        │   └── score_display.dart
        └── renderer/
            └── bubble_renderer.dart
```

## Test Strategy

| Area | Test Type | Location |
| ------ | ----------- | ---------- |
| Domain | Unit tests (engine rules, descent, determinism) | `test/engine_test.dart`, `test/descent_test.dart`, `test/engine_determinism_test.dart` |
| ViewModels | Unit tests (game and start-screen behavior) | `test/gameplay/viewmodel/`, `test/start_screen/viewmodel/` |
| Start screen | Widget tests | `test/start_screen_test.dart` |
| Web assets | Asset and web configuration checks | `test/web_assets_test.dart` |
