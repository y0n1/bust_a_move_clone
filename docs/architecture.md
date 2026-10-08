# Architecture — Bust-A-Move Clone

Flutter app architecture: MVVM, layered logic, feature folders.

## Guiding Principles

| Principle | Application |
|-----------|-------------|
| **Unidirectional Data Flow** | UI → Events → Logic → State → UI rebuild. No cross-layer mutations. |
| **Separation of Concerns** | Each layer owns its data and logic; layers communicate through well-defined boundaries. |
| **MVVM Pattern** | View (Flutter widgets) → ViewModel (state + business logic) → Model (domain entities). |
| **Feature-Based Folders** | Group by feature, not by technology. Each feature owns its UI, logic, and tests. |
| **Immutable State** | `GameState` snapshots; engine returns new instances. No in-place mutations. |
| **Pure Dart Domain** | Domain layer (`lib/game/`) has zero Flutter dependencies. Fully testable headlessly. |

## Layering

```
┌─────────────────────────────────────────────┐
│  Presentation Layer (Flutter UI)            │
│  lib/start_screen/    lib/gameplay/ui/      │
├─────────────────────────────────────────────┤
│  Logic Layer (ViewModels, Use Cases)        │
│  lib/gameplay/logic/                        │
├─────────────────────────────────────────────┤
│  Domain Layer (Business Entities & Rules)   │
│  lib/game/  (model.dart, engine.dart)       │
├─────────────────────────────────────────────┤
│  Data Layer (Future: saves, config, assets) │
│  lib/gameplay/data/                         │
└─────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Contents | Dependencies |
|-------|----------|-------------|
| **Domain** (`lib/game/`) | `model.dart` (BubbleColor, Bubble, GameState, GameStatus), `engine.dart` (game rules, hex-grid, collision, scoring) | None — pure Dart |
| **Logic** (`lib/gameplay/logic/`) | GameViewModel (state management, game lifecycle), ScoreViewModel, LevelViewModel | Domain only |
| **UI** (`lib/gameplay/ui/`) | GameScreen, HUD widgets, bubble renderer, juice effects | Logic + Domain (read-only) |
| **UI** (`lib/start_screen/`) | StartScreen, level select, settings | Logic (read-only) |

## Folder Structure

```
lib/
├── main.dart                    # MaterialApp bootstrap
├── game/                        # Domain layer
│   ├── model.dart
│   └── engine.dart
├── start_screen/                # Start screen feature
│   ├── start_screen.dart
│   ├── start_viewmodel.dart
│   └── start_screen_test.dart
└── gameplay/                    # Gameplay feature
    ├── ui/
    │   ├── game_screen.dart
    │   ├── hud/
    │   │   ├── score_display.dart
    │   │   └── level_display.dart
    │   └── renderer/
    │       └── bubble_renderer.dart
    ├── logic/
    │   ├── game_viewmodel.dart
    │   └── game_events.dart
    └── data/
        └── game_config.dart
```

## Naming Conventions

| Layer | Suffix | Example |
|-------|--------|---------|
| ViewModels | `ViewModel` | `GameViewModel` |
| Events | `Event` | `ShootEvent` |
| Domain entities | POCOs | `GameState`, `Bubble` |
| UI widgets | Semantic name | `ScoreDisplay`, `BubbleRenderer` |
| Services | `Service` (future) | `SaveService` |

## State Management

**`setState` + ViewModel** (no external packages yet).

Rationale:
- App has < 2 screens — Riverpod/Provider is premature
- ViewModel pattern gives clean separation without boilerplate
- When the app grows beyond one screen, a lightweight state manager can be added
- Keeps the domain layer untouched and fully testable

## Test Strategy

| Layer | Test Type | Location |
|-------|-----------|----------|
| Domain | Unit tests (engine rules) | `test/engine_test.dart` |
| Domain | Unit tests (model invariants) | `test/model_test.dart` |
| Logic | Unit tests (ViewModel behavior) | `test/gameplay/logic/` |
| UI | Widget tests (HUD, renderer) | `test/gameplay/ui/` |
