# Project Conventions

## Workflow

- **No commits without explicit approval.** Never run `git commit` or `git push` without the user saying "commit" or equivalent. After making changes, present a summary and wait.

## Branching

- One issue → one branch → one PR.
- Branch naming: `fix/<short>`, `feat/<short>`, `ci/<short>`.
- Always start from up-to-date `main` (`git fetch && git checkout main && git pull origin main`).

## Commit format

- `fix(scope): description`
- `feat(scope): description`
- `ci(scope): description`
- `chore(scope): description`
- Body explains why, not what.

## PR process

- `--base main`
- Link issue in PR body: `Fixes #N`
- Update issue body with fix details and PR link.
- **Reflect Kanban board status.** Move the issue card to the correct column (In Progress → In Review → Done) as part of the task delivery. This is an inseparable part of delivering a task — never leave a card in "In Progress" after the work is done.

## Handoff before commit

Every feature/fix must include a handoff section before committing, with:

1. **Environment setup** — exact commands to build and run the app for testing (e.g., `flutter build web --release`, `python3 -m http.server 8400`, Chrome flags).
2. **How to verify** — step-by-step actions the tester should perform (click X, fire shots at Y, check Z).
3. **Expected results** — what the tester should see if the fix is correct.

Present this section, wait for approval, then commit.

---

## Project Board Reference

Full project board documentation is in [`docs/project-board.md`](../../docs/project-board.md). It consolidates:
- Board layout (columns and meanings)
- Task requirements (priority, branch, assignee)
- Workflow rules for agents
- Branch naming conventions
- Useful `gh` and `git worktree` commands
