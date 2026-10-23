# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Agent team charter and eight role definitions in `.github/agents/`, including
  the new Quality Engineer and DevOps Engineer roles.
- Quality artifacts: test strategy, release checklist, and a v1.0.0 baseline
  verification report under `docs/quality/`.
- Operations artifacts: deployment runbook, deployment log, and production
  baseline under `docs/ops/`.
- Kickoff triage proposal covering product, UX, quality, and platform work in
  `docs/status/2026-10-23-kickoff.md`.
- Product discovery, UX design, decision-log, release, quality, operations,
  and status artifact folders.

## [1.0.0] - 2026-10-23

### Added

- Playable Flutter web Bust-A-Move clone: hex-grid board, aiming, shooting,
  wall bounce, match-3 popping, chain reactions, detached-cluster drops, and
  wall descent.
- Level progression with five difficulty configs, lives, combo scoring, and
  score/level HUD.
- Juice pass: particle bursts, score popups, screen shake, cannon recoil, and
  projectile trail.
- Responsive canvas layout with viewport constraints and mobile support.
- MVVM architecture with pure-Dart domain, ViewModels, feature folders, and
  headless engine tests.
- CI: analyze + tests on pull requests; GitHub Pages deployment on `main`.

[Unreleased]: https://github.com/y0n1/bust_a_move_clone/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/y0n1/bust_a_move_clone/releases/tag/v1.0.0
