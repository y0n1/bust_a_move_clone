# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-10-28

> **Pending.** The tag is cut only after QE validates this release on
> `main` and issues a PASS report
> ([ADR 0002](docs/decisions/0002-validate-on-main.md)). Full detail and the
> version derivation are in the
> [release notes](docs/releases/release-notes/v1.1.0.md).

### Added

- **Post-deploy verification.** A `smoke` job runs
  `test/quality/post_deploy_check.py` against the *live* URL after every
  deploy and fails the run when the site is unhealthy: root `200`,
  `version.json` matching the release, every manifest icon and
  `favicon.png` answering with a real PNG signature, and headless Chrome
  reaching a playable start screen with no blocking console errors. A green
  deploy job no longer means an unverified production.
  (OPS-4 [#82](https://github.com/y0n1/bust_a_move_clone/issues/82),
  [PR #99](https://github.com/y0n1/bust_a_move_clone/pull/99))
- **Rollback without a revert.** `deploy-pages.yml` accepts
  `workflow_dispatch` with a required `ref`, so a known-good commit, tag, or
  branch can be redeployed without touching `main`; manual runs are labelled
  and annotated.
  (OPS-2 [#80](https://github.com/y0n1/bust_a_move_clone/issues/80),
  [PR #100](https://github.com/y0n1/bust_a_move_clone/pull/100))
- **The web bundle is built on every pull request.** A `build-web` job runs
  the byte-identical production command in parallel with analyze+test and
  reports bundle size on disk and gzipped, so a base-href typo or web-only
  compile error can no longer reach `main`.
  (OPS-3 [#81](https://github.com/y0n1/bust_a_move_clone/issues/81),
  [PR #94](https://github.com/y0n1/bust_a_move_clone/pull/94))
- **Release smoke suite.** `test/quality/release_smoke.py` drives the ten
  critical-path steps against a production `build/web` over the DevTools
  Protocol — zero third-party dependencies, no `chromedriver` or
  `flutter drive`, and player-side state read from Flutter's semantics tree
  rather than from inside the app.
  (QE-1 [#69](https://github.com/y0n1/bust_a_move_clone/issues/69),
  [PR #96](https://github.com/y0n1/bust_a_move_clone/pull/96))
- **Update-path coverage.** `test/quality/sw_update_check.py` and
  `docs/quality/sw-update.md` measure the route a new build actually takes
  to a player: the shipped service worker caches nothing, and Pages serves
  every asset at `cache-control: max-age=600`.
  (QE-8 [#76](https://github.com/y0n1/bust_a_move_clone/issues/76),
  [PR #102](https://github.com/y0n1/bust_a_move_clone/pull/102))
- **Engine determinism suite.** `test/engine_determinism_test.dart` proves
  same-seed initial states are equal, identical shoot/tick sequences produce
  identical states, and a 50-step level-2 replay reproduces — backed by
  value equality for `Bubble`, `Projectile`, and `GameState`.
  ([#106](https://github.com/y0n1/bust_a_move_clone/issues/106),
  [PR #107](https://github.com/y0n1/bust_a_move_clone/pull/107))
- **Bug regression template is now the default.** It is linked from the
  test strategy and was validated against a real shipping defect, which
  closed five gaps in it (notably a clock/tick-rate field and a
  test-harness field).
  (QE-10 [#78](https://github.com/y0n1/bust_a_move_clone/issues/78),
  [PR #105](https://github.com/y0n1/bust_a_move_clone/pull/105))
- **UX spec for the honest shot score** — implementation-ready, design
  only; nothing in the game changed yet.
  (UX-2 [#68](https://github.com/y0n1/bust_a_move_clone/issues/68),
  [PR #103](https://github.com/y0n1/bust_a_move_clone/pull/103))
- **Team guidance consolidated.** New `CONTRIBUTING.md`, refreshed `AGENTS.md`,
  `docs/agent-team.md`, `docs/architecture.md`, role files, and instructions;
  `.mcp.json` is git-ignored so a local API token cannot be committed.
  ([#106](https://github.com/y0n1/bust_a_move_clone/issues/106),
  [PR #107](https://github.com/y0n1/bust_a_move_clone/pull/107))
- **Dependency automation and a supply-chain gate.** Dependabot now schedules
  weekly `pub` and `github-actions` updates — minor and patch grouped, majors
  alone so each one gets read — and `dependency-review` fails any PR that
  introduces a dependency with a known advisory (`moderate`+, runtime scope),
  reporting the version that fixes it. Cadence, triage, and the gate's limits
  (SDKs, runner image, base-branch advisories, licences) are written down in
  `docs/ops/dependencies.md`. Note: `dependabot.yml` is read from the default
  branch, so it is inert until this release reaches `main`.
  (OPS-7 [#85](https://github.com/y0n1/bust_a_move_clone/issues/85),
  [PR #104](https://github.com/y0n1/bust_a_move_clone/pull/104))

### Changed

- **Flutter pinned to 3.47.1** in both the CI and deploy workflows,
  declared once as a workflow-level `FLUTTER_VERSION`, replacing the
  floating `channel: stable` that let two runs of one commit use different
  SDKs. Bump procedure documented in `docs/ops/deployment.md`.
  (OPS-1 [#79](https://github.com/y0n1/bust_a_move_clone/issues/79),
  [PR #93](https://github.com/y0n1/bust_a_move_clone/pull/93))

### Fixed

- Web icons shipped as base64 text instead of PNGs, one manifest icon that
  pointed at a file which never existed, and a deprecated Apple meta tag.
  Detected by a new `test/web_assets_test.dart`, which fails 3/3 on `v1.0.0`.
  ([#95](https://github.com/y0n1/bust_a_move_clone/issues/95),
  [PR #97](https://github.com/y0n1/bust_a_move_clone/pull/97))

### Known issues

- The score popup is never drawn: the FX clock accumulates the Ticker's
  *cumulative* duration, so it grows quadratically and every popup is
  expired before the painter reads it. Cosmetic only — scoring, matching,
  and progression are unaffected. Characterised in
  `docs/design/specs/honest-shot-score.md` and
  `docs/quality/reports/2026-10-23-qe10-template-trial.md`; the fix ships
  with the honest shot score (PB-01). Particle bursts share the same clock.
- A player with the tab already open can keep playing the previous build
  for up to ten minutes after a deploy, with no reload prompt
  (`max-age=600`; proposed fix is
  [#101](https://github.com/y0n1/bust_a_move_clone/issues/101)).
- No accessibility audit, performance budget, or cross-browser evidence yet
  (QE-3, QE-4, QE-5).

## [1.0.0] - 2026-10-23

### Added

- Agent team charter and eight role definitions in `.github/agents/`, including
  the new Quality Engineer and DevOps Engineer roles.
- Quality artifacts: test strategy, release checklist, and a v1.0.0 baseline
  verification report under `docs/quality/`.
- Operations artifacts: deployment runbook, deployment log, and production
  baseline under `docs/ops/`.
- Kickoff triage proposal covering product, UX, quality, and platform work in
  `docs/status/2026-10-23-kickoff.md`.
- Product discovery, UX design, decision-log, quality, operations, and
  status artifact folders.
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

### Known issues

- Web icons are served as base64 text and `manifest.json` declares a missing
  `icons/Icon-maskable-512.png`, so the favicon and install icons are broken and
  every load issues a 404. Presentation only — gameplay is unaffected. Fixed on
  `develop` by [PR #97](https://github.com/y0n1/bust_a_move_clone/pull/97); see
  the [release notes](docs/releases/release-notes/v1.0.0.md).
- No accessibility audit, performance budget, or cross-browser evidence yet
  (QE-3, QE-4, QE-5).

<!-- `[1.1.0]` points at the tag this release earns once QE PASSes on `main`; it
     does not exist until the release is tagged. -->
[Unreleased]: https://github.com/y0n1/bust_a_move_clone/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/y0n1/bust_a_move_clone/releases/tag/v1.1.0
[1.0.0]: https://github.com/y0n1/bust_a_move_clone/releases/tag/v1.0.0
