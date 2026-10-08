# AGENTS.md — Bust-A-Move Clone


This file is the entry point for any AI agent working in this workspace. It answers "Where am I?" and "Where do I go?"  
Read this file first, then navigate to the relevant sub-file depending your current task.

---

## 0. Project Identity

| Field | Value |
|-------|-------|
| **Type** | Flutter / Dart — Bust-A-Move clone (bubble-shooter arcade game) |
| **Language** | Dart (Flutter framework) |
| **Architecture** | Pure Dart domain (`lib/game/`) + Flutter UI (`lib/ui/`) |
| **State model** | Immutable `GameState` snapshots; engine returns new state per mutation |
| **Determinism** | `math.Random` seeded for reproducible tests |
| **Platform target** | Web (Chrome), Linux |

---

## 1. Navigation — Where do I go?

Read the section that matches your task. Each links to the authoritative source.

### A. Running & Building

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

### B. Architecture

| Subsystem | File | Role |
|-----------|------|------|
| Entry point | `lib/main.dart` | `MaterialApp` → start screen |
| Domain model | `lib/game/model.dart` | `BubbleColor`, `Bubble`, `Projectile`, `GameState`, `GameStatus` |
| Game engine | `lib/game/engine.dart` | Hex-grid, board gen, aiming, shooting, collision, match-3 pop, chain reactions, detached-cluster drop, wall descent, scoring, win/lose |
| UI | `lib/ui/game_screen.dart` | `CustomPainter` canvas, pointer input, 60 Hz ticker, HUD |
| Tests | `test/engine_test.dart`, `test/descent_test.dart` | Headless engine tests (no Flutter) |
| **Architecture plan** | `docs/architecture-plan.md` | MVVM, layered logic, feature folders, migration strategy |

### C. Board Geometry (Engine Cheat-Sheet)

- Rows stacked vertically; odd rows offset right by half a bubble (hex packing)
- Row 0 has `cols` cells; odd rows have `cols - 1`
- Board-space in bubble diameters: `(0,0)` = top-left, y grows down
- `Engine.centerOf(row, col)` returns cell center in board-space
- Cannon at `(cols / 2, rows + 1)`
- `Engine.neighborsOf(row, col)` returns 6 hex-neighbors (handles even/odd offset)

### D. Conventions

- Domain layer (`lib/game/`) is **pure Dart** — no Flutter imports. Tests must run headlessly.
- Engine returns **new `GameState`** snapshots per mutation; UI replaces wholesale. No `setState` gymnastics.
- Use `math.Random` for all randomness — tests are seeded and deterministic.
- No Riverpod / Provider yet; add only when the app grows beyond a single screen.
- Assets (sprites, sounds, fonts) go in `assets/` + declared in `pubspec.yaml` when the art pass lands.

---

## 2. Memory & Knowledge — What persists across sessions?

This project uses a **compounding knowledge base** pattern (Karpathy LLM Wiki). The wiki is a git-tracked collection of markdown files that grows richer with every session. Knowledge is compiled once, kept current, never re-derived.

### Wiki structure

| Path | Purpose |
|------|---------|
| `docs/bust_a_move_spec.md` | Original game design specification (immutable source) |
| `docs/architecture-plan.md` | App architecture: MVVM, layered logic, feature folders |
| `AGENTS.md` (this file) | Schema — the contract for how agents operate here |
| `memories/` | Persistent notes (see below) |

### Memory scopes

| Scope | Path | Lifetime | Content |
|-------|------|----------|---------|
| User memory | `/memories/` | Cross-session | Preferences, patterns, constraints, decisions |
| Session memory | `/memories/session/` | Current session only | Task context, in-progress notes |
| Repo memory | `/memories/repo/` | Local to this workspace | Build commands, project facts, verified practices |

### Operations

1. **Ingest** — When a new fact, decision, or lesson is discovered, record it in the appropriate memory file. Keep entries short — bullet points, not prose.
2. **Query** — When starting work, check `/memories/` for relevant notes before re-discovering knowledge from scratch.
3. **Lint** — Periodically, review memories for stale claims, contradictions, or orphans. Delete what no longer applies.

---

## 3. Current State

| Aspect | Status |
|--------|--------|
| Engine core | Complete — match-3, chain reactions, cluster drop, wall descent |
| UI | Functional — CustomPainter, pointer input, HUD |
| Tests | Partial — engine_test.dart covers core logic; descent_test.dart added |
| Levels | Single level |
| Assets | Not yet added |
| Sound | Not yet added |
| Architecture plan | Created — `docs/architecture-plan.md` (MVVM, feature folders, migration strategy) |

---

## 4. What NOT to do

- Do **not** add Flutter imports to `lib/game/`.
- Do **not** mutate `GameState` in place — always return a new instance.
- Do **not** add state management (Riverpod, Provider) until the app has more than one screen.
- Do **not** use non-deterministic randomness in the engine.
- Do **not** skip reading `/memories/` at session start.
