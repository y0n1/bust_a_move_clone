# Session — 2026-10-23 board monitoring & governance handover

## Phase 1 — Board population

- 27 kickoff proposals from `docs/status/2026-10-23-kickoff.md` filed as real
  **issues** #64–#90 on Project #3 (not draft issues).
- Gotcha: new issues **auto-add** to the project, so `gh project item-add` fails
  with "Content already exists". Made the script idempotent (look up the item).
- Gotcha: project-level `items.totalCount` lagged at 61 of 72 during the GitHub
  incident "Project updates delayed". Per-issue `projectItems` was correct.
  **Never delete/re-add items to force indexing** — it does not help.

## Phase 2 — Agent orchestration

Dispatched 7 agent runs producing 8 docs (1,916 lines):

| Agent | Output |
|-------|--------|
| Product Manager | `docs/product/vision.md`, `competitive-analysis.md`, `backlog.md` |
| UX Designer | `docs/design/design-system.md`, `ux-spec-bounce-aim-guide.md` |
| Quality Engineer | `docs/quality/bug-regression-template.md` |
| DevOps Engineer | `docs/ops/branch-protection.md` |
| Project Manager | `docs/status/standup-2026-10-23.md` |

Highest-value findings from those runs:
- **PB-01 is a live bug** — the score popup shows the running total, not the
  points gained. RICE 30.0, top of the backlog.
- **4 WCAG AA contrast failures** in the current palette (purple 2.37:1, death
  line 1.24:1, progress track 1.88:1, aim line 3.73:1). Bubble luminance is
  nearly flat, so **shape glyphs are mandatory**, not decorative.
- **Bounce aim guide needs no engine rule change** — one additive read-only
  `Engine.predictAim(...)`. A 2-bounce cap is provably maximal.
- **`main` is not unprotected** — a ruleset already blocks deletion and
  non-fast-forward. Missing: PR requirement, required checks (`analyze-test`),
  conversation resolution. **Requiring 1 approval would deadlock** a
  single-maintainer repo; the policy uses 0 approvals.

## Phase 3 — The Ready anomaly

16 of 27 issues moved Backlog → Ready between 02:07:24Z and 02:13:25Z, one at a
time. Ruled out: cron, local processes, and all 7 project built-in workflows.
The window overlapped the Project Manager subagent run, which reported zero
mutations. **Refused to revert** a possible Product Owner action — vindicated in
Phase 4 (the moves were theirs).

PR #91 merged as squash → `main` at `09ebc70`; deploy run `39948828182` succeeded
and production was verified (HTTP 200, `version.json` 1.0.0+1).

---

---

## Phase 4 — Product Owner decisions (2026-10-23)

**The Ready anomaly is RESOLVED: the Product Owner moved those 16 cards manually.**
They believed the team was waiting on them to decide what was Ready. They have
committed to stop moving cards without consulting the team. No rollback needed —
the moves stand.

| # | Decision | Consequence |
|---|----------|-------------|
| 1 | P3 is out of scope; reprioritise to P2 | Charter now says P0–P2 only; board has no P3 field option; QE-10 #78 and OPS-11 #89 re-rated P2 |
| 2 | Triage is the team's job (priority + branch + assignee) | Project Manager records it; assignee may be blank while agent-only |
| 3 | Ready is the team's call, not the Product Owner's | Product Owner may still override |
| 4 | Tagging/versioning/releases belong to the Project Manager | No Product Owner approval step; gates still apply |
| 5 | QE files every defect to the board immediately | PMgr triages it, then PM decides must-fix vs postpone |
| 6 | Team reviews and merges its own PRs | Ping the Product Owner only for decisions that need them |

### Authority model after this session

- **Product Owner (y0n1):** direction, gate waivers, branch protection, irreversible calls. Not in the routine delivery path.
- **Team:** triage, implement, review, merge, release. Self-governing within the gates.
- **Release-blocking defect gate:** QE + Product Manager own the call; only the Product Owner can override it in writing.

### Board state after triage

- 72 items: 45 Done / 16 Ready / 11 Backlog.
- 27 kickoff items triaged: **P0 = 3, P1 = 11, P2 = 13**, zero unprioritised, zero P3.
- Rank within each priority recorded both in board order and in each issue body
  (`rank N of M within P#`) so a re-sort cannot lose it.

### Files changed this phase (branch `docs/team-decisions-2026-10-23`)

Charter `docs/agent-team.md`; six agent files (`quality-engineer`,
`project-manager`, `product-manager`, `engine-developer`, `flutter-developer`,
`devops-engineer`); `AGENTS.md`; `docs/project-board.md`; kickoff doc; standup;
deployment log; repo board memory. Plus 8 new docs from the agent runs.
**No `lib/`, `test/`, `pubspec.yaml`, or workflow changes.**

### Open items awaiting the Product Owner

1. **Branch protection** — proposal written, not applied. Needs a decision.
2. **`v1.0.0` tag** — now the Project Manager's to create, but the release gate
   (QE PASS + no must-fix defect) has not been run.
3. **Vision Q1–Q9** — nine product questions in `docs/product/vision.md`.

---

## Phase 5 — Governance corrections (2026-10-23, continued)

Five corrections from the Product Owner, applied on top of Phase 4 before the
branch was pushed.

### 1. Merge the two manager roles into one PM

The owner asked to "merge the program and project manager duties into the product
manager role" and call them **PMs**. No *program* manager existed — the team had
a **Product Manager** and a **Project Manager**. Interpreted as merging those two
into a single **Product Manager (PM)**. The team went from **8 roles to 7**;
`.github/agents/project-manager.agent.md` was deleted (`git rm`).

### 2. Triage is split, not shared

Correction: "branch and assignee assignment is a devops task, PM must not be
involved." So:

- **PM** → priority (P0–P2) and rank only.
- **DevOps** → branch and assignee only.

Neither does the other's half; the PM is not consulted on branches or assignees.
Encoded in charter §2/§3/§4/§6, the PM agent (duty 8), the DevOps agent (new
Duty 1), and the board docs.

### 3. "commits, reviews, pushes, and merges their own PRs"

The team rule now includes **reviews**. Merge bar = CI green + one peer review.
No user approval, no QE verdict required to merge.

### 4. QE validates *after* the merge, E2E first

"PRs merged trigger QE work... passing criteria must exercise first E2E
validation of the feature or bug-fix."

- A merged PR is **unverified**. It stays **In review** until QE passes it.
- QE is the only role that moves a task to **Done**.
- QE's loop is: build the artifact → play the real path → watch for collateral
  damage → *then* read the diff → *then* map acceptance criteria to evidence.
- "The unit tests pass" is explicitly **not** end-to-end evidence.

**Reconciliation:** the owner said "as they land into the main branch", but
Gitflow routes feature PRs to `develop`. Resolution: QE validates on the PR's
**target branch** — `develop` for features/fixes/docs/ci, `main` for
`release/*` and `hotfix/*`. This satisfies both statements.

### 5. Gitflow + Conventional Commits

New ADR: `docs/decisions/0001-gitflow-and-conventional-commits.md` (status
`accepted`).

- `main` = production, deploys on push. `develop` = integration, QE validates here.
  *(Superseded by Phase 6 / ADR 0002: QE validates on `main`, not `develop`.)*
- Task branches cut from `develop`, PRs target `develop`.
- `release/<version>` and `hotfix/<version>` are the only branches that target
  `main`, and both are **back-merged into `develop`** in the same session.
- Commits: `type(scope): description`; `feat`→MINOR, `fix`/`perf`→PATCH,
  `!` + `BREAKING CHANGE:`→MAJOR. Scopes: engine, ui, hud, renderer, viewmodel,
  start, ci, docs, board, deps.
- The PM **derives** the release version from the commit history. If it does not
  match intent, fix the commits — never hand-edit the version.

### Unplanned: three colliding "P" scales

Rewriting the QE agent surfaced three different things all called P0–P3. Fixed:

| Scale | Owner | Now called |
|-------|-------|-----------|
| Board scheduling | PM | **P0–P2** (unchanged) |
| Defect severity | QE | **Critical / High / Medium / Low** |
| Browser test coverage | QE | **Tier 1 / 2 / 3** |

### Files changed this phase

`docs/decisions/0001-gitflow-and-conventional-commits.md` (new),
`docs/decisions/README.md`, `docs/agent-team.md`, `AGENTS.md`,
`docs/project-board.md`, `docs/quality/test-strategy.md`,
`docs/quality/bug-regression-template.md`, `.github/workflows/ci.yml`,
seven agent files (one deleted, six rewritten), and the repo/session memories.
**Still no `lib/`, `test/`, or `pubspec.yaml` changes.**

### Still awaiting the Product Owner

1. Push + PR — the owner reviews the branch first.
2. Create `develop` on the remote and protect it identically to `main`.
3. Branch protection on `main` — proposal only, not applied.
4. `v1.0.0` tag — PM's job, release gate not yet run.

---

## Phase 6 — the Product Owner's real workflow (2026-10-23, later)

The Product Owner dictated the actual handoff model. It contradicted parts of
Phase 5, so the charter and all seven agent files were rewritten around it.

### The four handoffs, verbatim intent

1. **PM** — triages/prioritises and moves tasks to **Ready** once the team agrees
   in planning. **No branch required for Ready.**
2. **Developer** (SME by domain) — intakes from Ready, creates the branch, writes
   the **acceptance rubric**, implements, updates docs, opens a PR, moves the task
   to **In review**. Review uses **at most two dev subagents in parallel** judging:
   sound · aligned with architecture · composable · maintainable (not over-engineered)
   · readable (self-documenting) · inline-documented where non-trivial. The
   implementor reconciles and merges. **Every push starts a new review round.**
3. **QE** — validates **after the PR is merged to `main`** (or to `release/*` for a
   release-time bug), **never** on `develop` or a task branch. PASS → **Done**;
   FAIL → evidence in the ticket + defect + back to **Ready** + notify PM, who
   schedules a developer ASAP.

### Decisions taken

- **QE owns `Done`.** The dev paragraph also said "moves the task to Done", which
  contradicts handoff 3. Judged a slip: a merged PR is unverified, and handoff 3 is
  the detailed, internally consistent one. **Flagged to the owner — trivially
  reversible.**
- **Validation surface = `main`.** Recorded as
  `docs/decisions/0002-validate-on-main.md`. Features land in `develop`, so a task
  sits **In review** from merge until its release reaches `main`. Long feedback
  loop, accepted.
- **Auto-deploy kept.** `main` still deploys on every push, so QE validates the
  live artifact. Accepted risk: a broken release is publicly visible until QE
  rejects it and a hotfix lands. Revisit trigger logged in ADR 0002 and the DevOps
  agent (two production QE FAILs in one cycle → propose gating `main` on the verdict).
- **Release order inverted.** The PM can no longer require "all tasks Done" before
  cutting a release — impossible when QE validates post-merge. New order: merge →
  deploy → QE PASS → **tag** `vX.Y.Z` → back-merge → delete branch.
- **Branch naming split preserved.** DevOps still names the branch and assigns it;
  the **developer creates** it on intake.

### Files changed this phase

`docs/agent-team.md` (§2–§7, §10, §12–§14 incl. a fully redrawn flowchart),
all seven `.github/agents/*.agent.md`, `AGENTS.md`, `docs/project-board.md`,
`docs/decisions/0001-…md` (amendment), `docs/decisions/0002-validate-on-main.md`
(new), `docs/quality/release-checklist.md`, `docs/quality/test-strategy.md`,
`docs/quality/bug-regression-template.md`, and the repo memories.
**Still no `lib/`, `test/`, or `pubspec.yaml` changes.**

### Still awaiting the Product Owner

Unchanged from Phase 5 — plus: confirm that **QE, not the developer, owns `Done`**.
