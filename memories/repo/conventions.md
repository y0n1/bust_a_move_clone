# Project Conventions

## Autonomy

- The team **commits, reviews, pushes, and merges its own PRs**. Do not stop to ask
  the user for approval before committing, pushing, or merging.
- The merge bar is **CI green plus up to two dev review sign-offs** (at most two
  subagents, in parallel). No user approval and no QE verdict are required to
  merge.
- **Every push to a PR starts a new review round.** Do not merge code that changed
  after its last review.
- The implementor merges. QE validates **on `main`, after the release ships**.
  Only QE moves a task to **Done**; a rejection sends it back to **Ready**.
- Ask the user only for decisions the team cannot make: scope changes, new
  hosting/providers, ADR reversals, branch-protection changes.

## Branching (Gitflow — ADR 0001)

- `main` = production, deploys on push. **QE validates here.**
- `develop` = integration. Every task lands here; releases are cut from here. QE
  does **not** validate here.
- Task branches are cut from **`develop`** and their PRs target **`develop`**.
- Only `release/<version>` and `hotfix/<version>` target `main`.
- Every release/hotfix merged to `main` is **back-merged into `develop`** in the
  same session.
- Never commit directly to `main` or `develop`.
- One issue → one branch → one PR → one worktree.
- Branch naming: `<type>/<short-slug>` (`feat/`, `fix/`, `docs/`, `ci/`,
  `refactor/`, `test/`). DevOps names it; **the developer creates it on intake**.
- A missing branch name never blocks a task from being **Ready**.

## Commit format (Conventional Commits)

- `feat(scope): description` → MINOR
- `fix(scope): description` / `perf(scope): …` → PATCH
- `refactor|docs|test|build|ci|style|chore(scope): …` → no bump
- Breaking change: `!` before the colon **and** a `BREAKING CHANGE:` footer → MAJOR
- Scopes: `engine`, `ui`, `hud`, `renderer`, `viewmodel`, `start`, `ci`, `docs`,
  `board`, `deps`
- Footers: `Refs: #N`, `Fixes: #N`. Subject ≤72 chars, imperative, no trailing period.
- Body explains why, not what.
- The PM derives the release version from the commit history. If the derived
  version is wrong, fix the commits — do not hand-edit the version.

## PR process

- `--base develop` (except `release/*` and `hotfix/*`, which use `--base main`).
- Link the issue in the PR body: `Fixes #N`.
- Update the issue body with fix details and the PR link.
- **Write the acceptance rubric in the task before writing code.** QE validates
  against it; a missing or untestable rubric is itself a FAIL.
- **Reflect Kanban board status.** Move the card as work progresses
  (In progress → In review). Never leave a card in "In progress" when the PR is
  open, never move a card to "Done", and never send a rejected card anywhere but
  **Ready**.

## Handoff in the PR body

Every feature/fix PR includes a handoff section:

1. **Environment setup** — exact commands to build and run the app for testing
   (e.g., `flutter build web --release`, `python3 -m http.server 8400`, Chrome flags).
2. **How to verify** — step-by-step actions the tester should perform.
3. **Expected results** — what the tester should see if the fix is correct.

QE uses this section as the script for end-to-end validation **on `main`** after
the release ships.

---

## Project Board Reference

Full project board documentation is in [`docs/project-board.md`](../../docs/project-board.md). It consolidates:
- Board layout (columns and meanings)
- Triage split (PM: priority + rank; DevOps: branch **name** + assignee)
- Workflow rules for agents
- Branch naming conventions
- Useful `gh` and `git worktree` commands
