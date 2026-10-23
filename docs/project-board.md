# Project Board — Bust-A-Move Clone

> **Location:** `y0n1/bust_a_move_clone` GitHub repository  
> **URL:** `https://github.com/users/y0n1/projects/3` (GitHub Project, Kanban)  
> **Workflow source:** `AGENTS.md` section 4 + `.copilot/instructions/dev-workflow.instructions.md`

---

## Board Layout

| Column | Meaning |
|--------|---------|
| **Backlog** | Not started: untriaged, lower priority, or blocked. No branch expected. |
| **Ready** | Triaged: priority + rank (PM) and acceptance criteria. **A branch is not required.** Agents pick from here. |
| **In progress** | Agent is actively working on the task branch it created. |
| **In review** | PR open for review, **or** merged into `develop` and waiting for its release to reach `main` so QE can validate it. |
| **Done** | QE validated the change end-to-end **on `main`** (or on `release/*` for a release-time fix) against the developer's acceptance rubric. |

---

## Triage (who fills what)

Triage is **split**, not shared. Neither role does the other's half.

| Field | Owner | Notes |
|-------|-------|-------|
| **Priority** (P0–P2) + rank | **PM** | There is no P3. Board order top-to-bottom is the rank within a priority. |
| **Branch name** | **DevOps** | Gitflow name, `<type>/<slug>`. The **developer creates** the branch on intake. |
| **Assignee** | **DevOps** | May be left blank. |

The PM does not set branch names or assignees and is not consulted on them.
DevOps does not set priority or rank.

**None of these fields block `Ready`.** The PM moves a task to `Ready` when the
team agrees during planning that it is understood and buildable. If DevOps has
not named a branch yet, the developer picks a Conventional-Commit-shaped name
and starts anyway.

---

## Workflow Rules (What the agent MUST do)

1. Only pick tasks in **Ready** state.
2. Work through tasks in priority order until exhausted.
3. Never commit directly to `main` or `develop` — all work goes through a pull
   request, per [ADR 0001](decisions/0001-gitflow-and-conventional-commits.md).
4. Use a dedicated worktree per task to avoid conflicts.
5. **Create the task branch off `develop`** on intake, synced with
   `origin/develop`, and **write the acceptance rubric before writing code**.
6. Open a PR, run a review round of **at most two developer subagents in
   parallel**, reconcile, and merge your own PR once CI is green and disputes are
   settled. No user approval is needed. **Every push starts a new review round.**
7. Transition task status as work progresses:

| From | To | When |
|------|----|------|
| Backlog | Ready | Team agrees during planning; **PM** records priority and rank. No branch required. |
| Ready | In progress | Developer creates the branch and writes the acceptance rubric |
| In progress | In review | PR is opened, and stays In review after the implementor merges it |
| In review | Done | **QE** validated the change end-to-end on `main` against the rubric |
| In review | Ready | **QE** rejected it — evidence is attached to the task and the PM schedules a developer |

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
`release/<version>` and `hotfix/<version>` target `main`. QE validates on `main`,
never on `develop` or on a task branch, and DevOps deletes a task branch once QE
passes its task.

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

