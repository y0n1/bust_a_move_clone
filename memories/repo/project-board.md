# Project Board

## GitHub Project

- **Name**: Bust A Move - Kanban
- **Number**: 3
- **Owner**: y0n1
- **Type**: ProjectV2 (Kanban)

## Fields

| Field | Type | Notes |
|-------|------|-------|
| Status | SingleSelect | Backlog, Ready, In progress, In review, Done |
| Priority | SingleSelect | P0, P1, P2, P3 |
| Assignees | User | |
| Labels | MultiSelect | |
| Linked pull requests | PR | |

## Commands

```bash
# List projects
gh project list

# List items
gh project item-list 3 --owner y0n1

# View project
gh project view 3 --owner y0n1 --web

# Create item
gh project item-create 3 --owner y0n1 --title "Title" --body "Body"

# Edit item
gh project item-edit <item-id> --title "New title"
```

## State snapshot — 2026-10-23

- 45 items, all **Done**; Backlog, Ready, In progress, and In review are empty.
- No implementation may start until the user triages tasks into **Ready**.
- Triage proposals for the new QE/DevOps roles and the product/UX kickoff:
  `docs/status/2026-10-23-kickoff.md`.
- Board rules and status transitions: `docs/agent-team.md` §5 and `docs/project-board.md`.