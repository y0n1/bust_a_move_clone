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
| Priority | SingleSelect | P0, P1, P2 only — **no P3 option** despite charter P0–P3 |
| Assignees | User | |
| Labels | MultiSelect | |
| Linked pull requests | PR | |

### IDs (project #3)

- Project node ID: `PVT_kwHOAEGiN84Bl6Cv`
- Status field: `PVTSSF_lAHOAEGiN84Bl6CvzhklC-c`
  - Backlog `f75ad846` · Ready `61e4505c` · In progress `47fc9ee4` · In review `df73e18b` · Done `98236657`
- Priority field: `PVTSSF_lAHOAEGiN84Bl6CvzhklDLc`
  - P0 `79628723` · P1 `0a877460` · P2 `da944a9c`

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

# Move an issue to Backlog
gh project item-edit --id <PVTI_id> --project-id PVT_kwHOAEGiN84Bl6Cv \
  --field-id PVTSSF_lAHOAEGiN84Bl6CvzhklC-c --single-select-option-id f75ad846
```

## Gotchas

- New issues are **auto-added** to the project; `gh project item-add` then fails
  with `Content already exists in this project`. Look the item up instead of adding.
  (`gh project item-add` is idempotent — it returns the existing item ID.)
- `gh project item-list --limit` and the GraphQL `items` connection can lag /
  truncate after bulk creation. Verify per issue with
  `issue(number:N) { projectItems { ... fieldValueByName(name:"Status") } }`.
- **2026-10-23:** GitHub incident "Project updates delayed" — newly added items
  took much longer than expected to appear in `items`/`item-list` while the
  per-issue `projectItems` query was already correct. Trust the per-issue query
  during incidents; do not delete/re-add items to "force" indexing (it does not help).
- Board items are real **Issues** (not draft issues), so they have numbers and URLs.

## State snapshot — 2026-10-23

- **72 items**: 45 **Done**, 27 **Backlog** (issues #64–#90), nothing in Ready,
  In progress, or In review.
- No implementation may start until the user triages tasks into **Ready**.
- Triage proposals: `docs/status/2026-10-23-kickoff.md` (§4 maps every ID to its issue number).
- Priorities are intentionally **unset** on the 27 new items — only the user triages.
- Board rules and status transitions: `docs/agent-team.md` §5 and `docs/project-board.md`.