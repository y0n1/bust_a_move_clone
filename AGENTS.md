# AGENTS.md — Bust-A-Move Clone

Entry point for AI agents in this repository. Read this file, then use the
linked guides for details.

## Project

A single-player Bust-A-Move browser game built with Flutter and Dart, deployed
to [GitHub Pages](https://y0n1.github.io/bust_a_move_clone/). Product scope is
in the [vision](docs/product/vision.md) and [game spec](docs/bust_a_move_spec.md);
architecture and code map are in the [architecture guide](docs/architecture.md).

## Run and verify

| Task | Command |
| ------ | --------- |
| Install dependencies | `flutter pub get` |
| Run in Chrome | `flutter run -d chrome` |
| Run quality gate | `flutter analyze --fatal-infos && flutter test test/` |

Build for GitHub Pages with:

```bash
flutter build web --release --base-href /bust_a_move_clone/
```

See the [deployment guide](docs/ops/deployment.md) for release and hosting
details.

## Project guides

| Topic | Guide |
| ------- | ------- |
| Architecture and code map | [Architecture](docs/architecture.md) |
| Team roles and contribution workflow | [Contributing](CONTRIBUTING.md) |
| Board process | [Project board](docs/project-board.md) |
| Test strategy and release checks | [Quality docs](docs/quality/) |
| Deployment and operations | [Operations docs](docs/ops/) |

## Working rules

- Read relevant notes in `memories/repo/` and `memories/session/`; record
  durable project learnings in the appropriate memory file.
- Follow [contribution rules](CONTRIBUTING.md) and preserve the boundaries in
  the [architecture guide](docs/architecture.md).
- Keep documentation current with the code it describes. When a change
  invalidates a guide — the architecture code map, specs, board process,
  ops runbooks — update the affected doc in the same PR, and record durable
  learnings in `memories/`. Never leave a doc contradicting the code.
