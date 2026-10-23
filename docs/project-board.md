# Project Board — Bust-A-Move Clone

> **Location:** `y0n1/bust_a_move_clone` GitHub repository  
> **URL:** `https://github.com/users/y0n1/projects/3` (GitHub Project, Kanban)  
> **Workflow source:** `AGENTS.md` section 4 + `.copilot/instructions/dev-workflow.instructions.md`

---

## Board Layout

| Column | Meaning |
|--------|---------|
| **Backlog** | Not started: untriaged, lower priority, or blocked. No branch expected. |
| **Ready** | Triaged: priority + rank (PM), branch + assignee (DevOps), acceptance criteria. Agents pick from here. |
| **In progress** | Agent is actively working on the associated branch. |
| **In review** | PR open for peer review, **or** merged and awaiting QE end-to-end validation. |
| **Done** | QE validated the change end-to-end post-merge (and, for releases, production is verified). |

---

## Triage (who fills what)

Triage is **split**, not shared. Neither role does the other's half.

| Field | Owner | Notes |
|-------|-------|-------|
| **Priority** (P0–P2) + rank | **PM** | There is no P3. Board order top-to-bottom is the rank within a priority. |
| **Branch** | **DevOps** | Gitflow name, cut from `develop`. |
| **Assignee** | **DevOps** | May be left blank. |

The PM does not set branches or assignees and is not consulted on them. DevOps
does not set priority or rank.

---

## Workflow Rules (What the agent MUST do)

1. Only pick tasks in **Ready** state.
2. Work through tasks in priority order until exhausted.
3. Never commit directly to `main` or `develop` — all work goes through a pull
   request, per [ADR 0001](decisions/0001-gitflow-and-conventional-commits.md).
4. Use a dedicated worktree per task to avoid conflicts.
5. **Branch off `develop`**, synced with `origin/develop`, before starting work.
6. Commit, review, push, and merge your own PRs once CI is green and a peer has
   reviewed. No user approval is needed.
7. Transition task status as work progresses:

| From | To | When |
|------|----|------|
| Backlog | Ready | Definition of Ready met; **PM** records priority and rank, **DevOps** records branch and assignee |
| Ready | In progress | Agent checks out the branch |
| In progress | In review | PR is opened |
| In review | Done | **QE** validated the change end-to-end on the target branch |

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

Task branches are cut from `develop` and their PRs target `develop`. Only
`release/<version>` and `hotfix/<version>` target `main`.

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

