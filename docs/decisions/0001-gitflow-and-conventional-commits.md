# 0001 — Gitflow branching and Conventional Commits

- **Status:** accepted
- **Date:** 2026-10-23
- **Owners:** y0n1 (Product Owner)
- **Deciders:** Product Owner; executed by the PM and DevOps Engineer
- **Related:** [`docs/agent-team.md`](../agent-team.md) §10, [`docs/project-board.md`](../project-board.md), `.github/workflows/ci.yml`

## Context

Until now the repository used a single long-lived branch: every PR targeted
`main`, and `main` was simultaneously the integration branch, the release
branch, and the deployed branch. Three problems followed from that:

1. **`main` was never a stable release line.** A half-finished integration was
   one merge away from being deployed to production.
2. **Deploys were triggered by anything.** `deploy-pages.yml` has no path filter,
   so a docs-only merge to `main` rebuilt and redeployed the game.
3. **Commit messages carried no machine-readable intent.** Version numbers were
   chosen by hand, so the `CHANGELOG.md` and `pubspec.yaml` version drifted from
   what actually shipped.

We need a branching model where `main` means "production, always", plus commit
semantics that make the version number derivable from history instead of
guessed.

## Options considered

1. **Gitflow + Conventional Commits** — long-lived `main` (production) and
   `develop` (integration); short-lived `feature/*`, `release/*`, `hotfix/*`;
   commit messages typed `feat:`, `fix:`, `docs:`… with SemVer derived from the
   types.
   - *Pros:* `main` is a clean release line; every deploy corresponds to a
     release; version bumps become mechanical; changelog is generatable; hotfixes
     do not drag unreleased features along; matches how the team already works
     (one task = one branch = one PR).
   - *Cons:* two long-lived branches to keep in sync; release and hotfix merges
     must be back-merged into `develop` or the branches diverge; more ceremony
     for a small team.
2. **Trunk-based with release tags** — everyone commits to `main` behind feature
   flags; releases are tags.
   - *Pros:* simplest; no merge-back problem; continuous integration in the
     literal sense.
   - *Cons:* requires feature-flag discipline and a fast, trusted E2E suite,
     neither of which exists yet; an unfinished feature is one bad merge from
     production.
3. **Do nothing** — keep PRs → `main`.
   - *Pros:* zero migration cost.
   - *Cons:* the three problems above persist and get worse as the team grows.

## Decision

**Adopt Gitflow and Conventional Commits.** Confidence: high.

### Branches

| Branch | Lifetime | Cut from | Merges into | Purpose |
|--------|----------|----------|-------------|---------|
| `main` | permanent | — | — | Production line. Every commit is a released, deployed version. Deploy trigger. |
| `develop` | permanent | `main` (once) | — | Integration line. Every completed task lands here; releases are cut from here. QE does **not** validate here. |
| `feat/<slug>` `fix/<slug>` `docs/<slug>` `ci/<slug>` `refactor/<slug>` `test/<slug>` | short | `develop` | `develop` | One task, one branch, one PR. |
| `release/<version>` | short | `develop` | `main` **and** `develop` | Version bump, `CHANGELOG.md`, release notes only. No new features. |
| `hotfix/<version>` | short | `main` | `main` **and** `develop` | Production emergency only. |

**Back-merge rule.** Every `release/*` and `hotfix/*` merged into `main` **must**
be merged back into `develop` in the same working session. Skipping the
back-merge is the single most common Gitflow failure: `develop` silently loses
the version bump and the next release regresses.

**PR base branch.** Feature work targets `develop`. Only `release/*` and
`hotfix/*` target `main`.

**Validation surface.** QE validates end-to-end on `main` — the shippable
artifact — and on a `release/*` branch only when a defect is discovered during a
release. QE never validates `develop` or a feature branch. See
[ADR 0002](0002-validate-on-main.md).

### Commits — Conventional Commits v1.0.0

Format: `<type>(<scope>)?: <description>` — imperative mood, lower-case, no
trailing period.

| Type | Use for | SemVer effect |
|------|---------|---------------|
| `feat` | New player-visible capability | **MINOR** |
| `fix` | Bug fix | **PATCH** |
| `perf` | Performance improvement, no behavior change | PATCH |
| `refactor` | Restructuring, no behavior change | none |
| `docs` | Documentation only | none |
| `test` | Tests only | none |
| `build` | Build system, `pubspec.yaml` dependencies | none |
| `ci` | Workflows, pipeline | none |
| `style` | Formatting, whitespace | none |
| `chore` | Maintenance, no src or test change | none |
| `revert` | Reverts a previous commit; reference the SHA | matches reverted commit |

- **Breaking change:** `!` before the colon (`feat(engine)!: ...`) **and** a
  `BREAKING CHANGE:` footer. Bumps **MAJOR**.
- **Scope** is the touched area: `engine`, `ui`, `hud`, `renderer`, `viewmodel`,
  `start`, `ci`, `docs`, `board`, `deps`.
- **Footer** `Refs: #N` or `Fixes: #N` links the board task. `Fixes:` closes it.
- The subject line stays under 72 characters; the body explains **why**.

### Versioning — SemVer derived from history

`MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`.

Since the project is at `1.0.0`, the pre-1.0 escape hatch no longer applies:
`feat` → MINOR, `fix`/`perf` → PATCH, breaking → MAJOR, everything else bumps
nothing on its own.

The PM derives the next version from the commits between the last tag and the
release point. If the derived version does not match the intent, the commits are
wrong — fix the commits, do not hand-edit the version.

## Consequences

**Positive**
- `main` becomes a trustworthy release line; anything on it is deployed and
  verified.
- Docs-only merges stop triggering production deploys, because they now land on
  `develop`.
- The version number and the changelog become mechanical and auditable.
- Hotfixes can ship without dragging unreleased `develop` work along.

**Negative**
- Two long-lived branches to protect and keep in sync.
- The back-merge is a manual step that will be forgotten unless it is in the
  release checklist. It is.
- CI must gate PRs into `develop` as well as `main`.
- Because QE validates on `main`, a feature merged to `develop` stays **In
  review** until its release ships. The feedback loop from "code merged" to
  "validated" is measured in releases, not minutes. This is the price of testing
  the real artifact, and it is why the acceptance rubric must be written before
  the code.

**Follow-up work**
- Create `develop` from `main` and protect it identically to `main`.
- Add `develop` to the `pull_request` trigger in `ci.yml`; keep
  `deploy-pages.yml` on `main` only.
- The `analyze-test` check name is used by both branch rulesets.
- Add a commit-message check (or rely on review) once the team has run this for
  a few iterations.

## Revisit trigger

Reopen this decision if any of the following becomes true:

- Back-merges are missed more than once, making `develop` unreliable.
- The team adopts feature flags and a fast, trusted E2E suite.
- The merge ceremony costs more than it saves on a two-person cadence.
