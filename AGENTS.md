# AGENTS.md — Bust-A-Move Clone


This file is the entry point for any AI agent working in this workspace. It answers "Where am I?" and "Where do I go?"  
Read this file first, then navigate to the relevant sub-file depending your current task.

---

## 0. Project Identity

| Field | Value |
|-------|-------|
| **Type** | Flutter / Dart — Bust-A-Move clone (bubble-shooter arcade game) |
| **Language** | Dart (Flutter framework) |
| **Architecture** | Pure Dart domain (`lib/game/`) + Flutter UI (`lib/gameplay/ui/`, `lib/start_screen/`) |
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
| Format | `dart format .` |
| Lint fix | `dart fix --apply` |
| Run single test | `flutter test path/to/file_test.dart` |
| Run web (debug) | `flutter run -d chrome` |
| Build web release | `flutter build web --release` |
| Build production web | `flutter build web --release --base-href /bust_a_move_clone/` |
| Quality gate | `flutter analyze --fatal-infos && flutter test test/` |
| Clean | `flutter clean` |

> **Production:** `https://y0n1.github.io/bust_a_move_clone/` — deployed from
> `main` by `.github/workflows/deploy-pages.yml`. See
> [`docs/ops/deployment.md`](docs/ops/deployment.md).

### B. Architecture

| Subsystem | File | Role |
|-----------|------|------|
| Entry point | `lib/main.dart` | `MaterialApp` → start screen |
| Domain model | `lib/game/model.dart` | `BubbleColor`, `Bubble`, `Projectile`, `GameState`, `GameStatus` |
| Game engine | `lib/game/engine.dart` | Hex-grid, board gen, aiming, shooting, collision, match-3 pop, chain reactions, detached-cluster drop, wall descent, scoring, win/lose |
| Start ViewModel | `lib/start_screen/viewmodel/start_screen_viewmodel.dart` | Creates a fresh `GameViewModel` per session |
| Start View | `lib/start_screen/start_screen.dart` | Title, PLAY button, instructions |
| Game ViewModel | `lib/gameplay/viewmodel/game_viewmodel.dart` | Owns `Engine` + `GameState`, 60 Hz `Ticker`, aim/fire/restart, juice FX state, layout math |
| Game View | `lib/gameplay/ui/game_screen.dart` | Thin `ChangeNotifier` listener: `CustomPaint`, pointer input, HUD, status overlay |
| Renderer | `lib/gameplay/ui/renderer/bubble_renderer.dart` | `GamePainter` + juice types (`ScorePopup`, `Particle`, `ParticleBurst`) |
| HUD | `lib/gameplay/ui/hud/` | `ScoreDisplay`, `LevelDisplay` |
| Tests | `test/engine_test.dart`, `test/descent_test.dart`, `test/start_screen_test.dart` | Headless engine and widget tests |
| ViewModel tests | `test/gameplay/viewmodel/`, `test/start_screen/viewmodel/` | ViewModel behavior without widgets |

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
- MVVM layering: **View** (`*_screen.dart`) is dumb and only listens/forwards input; **ViewModel** (`*/viewmodel/*_viewmodel.dart`) owns state, ticker, and calls into the engine. Views never call `Engine` directly.
- ViewModels extend `ChangeNotifier`; Views subscribe with `addListener`/`removeListener` and `setState`.
- No Riverpod / Provider — plain `ChangeNotifier` is enough until dependency injection becomes painful.
- Feature-first folders: `lib/gameplay/` and `lib/start_screen/`, each with `ui/` + `viewmodel/`.
- Assets (sprites, sounds, fonts) go in `assets/` + declared in `pubspec.yaml` when the art pass lands.

### E. Agent Team

The project is delivered by an eight-role AI team. Read the charter before acting:
**[`docs/agent-team.md`](docs/agent-team.md)**.

| Role | Agent file | Owns |
|------|-----------|------|
| Product Manager | `.github/agents/product-manager.agent.md` | `docs/product/` — vision, competitive analysis, briefs, backlog |
| UX Designer | `.github/agents/ux-designer.agent.md` | `docs/design/` — design system, UX specs |
| Engine Developer | `.github/agents/engine-developer.agent.md` | `lib/game/`, engine tests |
| Flutter Developer | `.github/agents/flutter-developer.agent.md` | `lib/gameplay/ui/`, `lib/start_screen/`, ViewModels |
| Multiplayer Developer | `.github/agents/multiplayer-developer.agent.md` | future `lib/net/`, `server/`, net tests |
| Quality Engineer | `.github/agents/quality-engineer.agent.md` | `docs/quality/`, `test/quality/`, release verification |
| DevOps Engineer | `.github/agents/devops-engineer.agent.md` | `.github/workflows/`, `docs/ops/`, production |
| Project Manager | `.github/agents/project-manager.agent.md` | board, `CHANGELOG.md`, `docs/releases/`, `docs/status/` |

**Team rules:** only **Ready** tasks are implemented; only the **user** triages
(priority, branch, assignee); one task = one worktree = one branch = one PR;
no commits without approval; no direct commits to `main`. PM/UX/QE/DevOps/PMgr
never write production code. QE signs off before merge and release; DevOps
verifies every production deploy and owns rollback.

---

## 2. Memory & Knowledge — What persists across sessions?

This project uses a **compounding knowledge base** pattern (Karpathy LLM Wiki). The wiki is a git-tracked collection of markdown files that grows richer with every session. Knowledge is compiled once, kept current, never re-derived.

### Wiki structure

| Path | Purpose |
|------|---------|
| `docs/bust_a_move_spec.md` | Original game design specification (immutable source) |
| `docs/agent-team.md` | Team charter — roles, RACI, workflow, DoR/DoD, releases |
| `docs/product/` | Vision, competitive analysis, feature briefs, backlog |
| `docs/design/` | Design system and implementation-ready UX specs |
| `docs/decisions/` | Architecture/product decision records (ADRs) |
| `docs/releases/` | Roadmap and release notes |
| `docs/status/` | Standups and progress reports |
| `docs/quality/` | Test strategy, release checklist, verification reports |
| `docs/ops/` | Deployment runbook, deployment log, incident runbooks |
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
| Architecture | Complete — MVVM, feature folders, ViewModels own state (PR #62) |
| UI | Functional — CustomPainter, pointer input, HUD |
| Tests | 45 passing — engine, descent, start screen, ViewModel units |
| Levels | 5 configs (`LevelConfig.all`), endless above 5 |
| Assets | Not yet added |
| Sound | Not yet added |
| Quality | Baseline green — 45 tests passing, `flutter analyze --fatal-infos` clean |
| Production | Live at `https://y0n1.github.io/bust_a_move_clone/`; deploy verified manually |
| Board | All tasks Done — no Ready work queued |
| Team | Defined — 8 agents in `.github/agents/`; discovery and quality kickoff in progress |

---

## 4. What NOT to do

- Do **not** add Flutter imports to `lib/game/`.
- Do **not** mutate `GameState` in place — always return a new instance.
- Do **not** call `Engine` from a View — go through the ViewModel.
- Do **not** add Riverpod / Provider — plain `ChangeNotifier` until DI becomes painful.
- Do **not** use non-deterministic randomness in the engine.
- Do **not** implement anything without a **Ready** board task.
- Do **not** invent task priority, branch, or assignee — only the user triages.
- Do **not** let PM, UX, QE, DevOps, or Project Manager roles edit `lib/`.
- Do **not** merge without a QE verdict, or release without a QE **PASS**.
- Do **not** deploy without a green pipeline and post-deploy production verification.
- Do **not** weaken, skip, or silence quality gates to hit a date.
- Do **not** commit, push, tag, or release without explicit user approval.
- Do **not** re-litigate a recorded ADR without new evidence.
- Do **not** skip reading `/memories/` at session start.
