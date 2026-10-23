# 0002 — Validate on `main`, not on `develop`

- **Status:** accepted
- **Date:** 2026-10-23
- **Owners:** y0n1 (Product Owner)
- **Deciders:** Product Owner; executed by the Quality Engineer, PM, and DevOps Engineer
- **Related:** [`0001-gitflow-and-conventional-commits.md`](0001-gitflow-and-conventional-commits.md), [`docs/agent-team.md`](../agent-team.md) §4, `.github/workflows/deploy-pages.yml`

## Context

ADR 0001 split integration (`develop`) from production (`main`). That raised an
immediate question: **which artifact does QE validate?**

The obvious answer — validate whatever branch the PR merged into — means
validating `develop` for most tasks. That is cheap and fast, and it is what most
teams do. It is also a lie.

Validating `develop` proves that *some* combination of code works in a branch
nobody ships. It cannot catch:

- a release-only failure: the version bump, the `--base-href` in the production
  build, the Pages deploy, the service-worker update path;
- an interaction between two features that merged into `develop` separately and
  were never together in a shippable artifact;
- anything about the real, deployed player experience.

The team had already adopted the principle that **a merged PR is unverified**.
The question was where verification happens, not whether.

## Options considered

1. **Validate on the target branch** (`develop` for features, `main` for
   releases). Fast feedback, cheap, and it is the default. But it validates a
   non-shippable artifact and cannot observe release-specific failures.
2. **Validate on `main` after the release ships.** Slower feedback: a feature
   merged to `develop` stays unvalidated until its release lands. But every
   verdict is issued against the exact artifact players get.
3. **Validate both** — a light check on `develop`, full validation on `main`.
   Doubles QE's workload, and the light check still proves nothing about
   production.

## Decision

**QE validates end-to-end on `main`, against the acceptance rubric the developer
wrote before implementing.**

- Features merge to `develop` and their task stays **In review**. It becomes
  **Done** only when the release carrying it reaches `main` and QE passes it.
- When a defect is discovered *during* a release, QE validates the fix on the
  `release/<version>` branch, before it merges. That is the only exception.
- **QE never validates `develop` and never validates a `feat/*`, `fix/*`, or
  other task branch.**
- On **PASS**, QE moves the task to **Done** and DevOps deletes the branch.
- On **FAIL**, QE attaches the evidence to the task, files the defect, moves the
  task back to **Ready**, and notifies the PM, who re-prioritises it and
  schedules a developer immediately.
- Because the rubric is the contract, the **implementor must write the
  acceptance rubric before writing code**. A missing or untestable rubric is
  itself a **FAIL**.

`deploy-pages.yml` keeps firing on every push to `main`. QE therefore validates
the live production artifact rather than a local build.

## Consequences

**Positive**
- Every QE verdict describes the real player artifact, including the production
  build, the base href, and the deploy.
- "Done" means "proven in production", not "compiled somewhere".
- The acceptance rubric becomes the shared contract between the implementor and
  the validator, so disagreements surface before code is written.
- No duplicate validation effort across branches.

**Negative**
- **Long feedback loop.** A feature merged to `develop` is unvalidated until its
  release ships. Mitigated by the review round at PR time and by CI, but not
  eliminated.
- **`In review` is a wide column.** It holds both "PR open" and "merged, waiting
  for a release". The board must distinguish these in the task text.
- **Unvalidated code is publicly live.** `main` deploys on push, so a broken
  release is visible to players until QE rejects it and a hotfix lands.
- A release can be blocked late: QE failure on `main` after the release merge
  means either a hotfix or a revert, not a quiet fix on `develop`.

## Revisit trigger

Reopen this decision if any of the following becomes true:

- A QE **FAIL** reaches production more than once in a release cycle — then gate
  the `main` deploy on the QE verdict instead of deploying first.
- Releases become infrequent enough that "In review" tasks routinely go stale,
  making the board a poor signal.
- The team adopts a trusted, automated E2E suite fast enough to validate
  `develop` continuously — at which point option 3 becomes affordable.
