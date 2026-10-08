# Project Board — Bust-A-Move Clone

> **Location:** `y0n1/bust_a_move_clone` GitHub repository  
> **URL:** `https://github.com/users/y0n1/projects/3` (GitHub Project, Kanban)  
> **Workflow source:** `AGENTS.md` section 4 + `.copilot/instructions/dev-workflow.instructions.md`

---

## Board Layout

| Column | Meaning |
|--------|---------|
| **Backlog** | Untriaged or future tasks. No branch expected. |
| **Ready** | Triaged, prioritized. Ready for work. Agents pick from here. |
| **In progress** | Agent is actively working on the associated branch. |
| **In review** | PR is open. Waiting for merge. |
| **Done** | PR merged or closed. |

---

## Task Requirements (What the user MUST provide)

Every task must include:

- **Priority** — establishes order of work (e.g., P1, P2, P3)
- **Upstream branch** — the feature branch to sync with `origin/main`
- **Assignee** — who is responsible (human or agent)

---

## Workflow Rules (What the agent MUST do)

1. Only pick tasks in **Ready** state.
2. Work through tasks in priority order until exhausted.
3. Never commit directly to `main` — all work goes through the board.
4. Use a dedicated worktree per task to avoid conflicts.
5. Sync the task branch with `origin/main` before starting work.
6. Transition task status as work progresses:

| From | To | When |
|------|----|------|
| Backlog | Ready | After triage (priority, branch, assignee) |
| Ready | In progress | Agent checks out the branch |
| In progress | In review | PR is opened |
| In review | Done | PR is merged or closed |

---

## Branch Naming Convention

```
<type>/<short-slug>
```

| Prefix | Use case |
|--------|----------|
| `feat/` | New feature |
| `fix/` | Bug fix |
| `test/` | Test additions |
| `refactor/` | Code restructuring |
| `docs/` | Documentation |
| `ci/` | CI/CD changes |

Examples: `feat/wall-descent`, `fix/match-3-off-by-one`, `refactor/engine-api`

---

## Useful Commands

### Ready Tasks (most common)

```bash
# List tasks in "Ready" state with priority
gh project item-list 3 --owner @me --limit 50 --format json \
  --jq '.items[] | select(.status.name == "Ready") |
    {number: .content.number, title: .content.title,
     priority: (.field_values[] | select(.name == "Priority") | .single_line_text)}'
```

### Task Management (CLI via `gh`)

```bash
# List all projects for this repo
gh project list -R y0n1/bust_a_move_clone

# List items in a specific project (replace <num> with project number)
gh project items <num> -R y0n1/bust_a_move_clone --limit 50

# Create a new project item (from an issue)
gh project item-add <num> -R y0n1/bust_a_move_clone --title "Task title" --issue <issue-number>

# List open PRs (quick "In review" check)
gh pr list -R y0n1/bust_a_move_clone --state open

# List branches with upstream tracking
git branch -vv | grep -v detached
```

### Worktree per Task

```bash
# Create a dedicated worktree for a task branch
git worktree add ../bust_a_move_clone_<task-slug> origin/<branch-name>

# List all worktrees
git worktree list

# Remove a worktree when done
git worktree remove <path>
```

### Board Discovery (first-time setup)

```bash
# Find project boards for a repo
gh project list -R y0n1/bust_a_move_clone

# Find the board URL directly
gh api repos/y0n1/bust_a_move_clone/projects | jq '.[] | {name, url, body_text}'
```

