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