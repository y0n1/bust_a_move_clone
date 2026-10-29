# Contributing

Start with [AGENTS.md](AGENTS.md) for project context and commands. This project
uses a role-based agent team; the roster, ownership, review process, and board
rules are defined in the [team charter](docs/agent-team.md) and
[project-board guide](docs/project-board.md).

## Work and review

- Implement work that is **Ready** on the board. The task must have an
  acceptance rubric before implementation.
- Follow the role boundaries in the team charter. The task-owning developer
  writes the rubric, implements, and opens the PR; peers review it.
- Link the issue from the PR (`Fixes #N`) and include the testing handoff
  described in the team charter.
- Merge only with CI green and the required developer review. QE validates
  after the change reaches `main`; only QE marks a task **Done**.

## Branches and commits

The project uses Gitflow and Conventional Commits. Task branches are cut from
`develop` and PRs target `develop`; only `release/*` and `hotfix/*` target
`main`. Release and hotfix changes are back-merged into `develop`.

Use the commit format and versioning rules in
[ADR 0001](docs/decisions/0001-gitflow-and-conventional-commits.md). The
[repository conventions](memories/repo/conventions.md) summarize branch,
commit, and PR requirements.

## Validate changes

Run the project quality gate before opening a PR:

```sh
flutter analyze --fatal-infos
flutter test test/
```

Keep the domain and presentation boundaries described in
[the architecture guide](docs/architecture.md), and do not weaken or skip
quality checks.
