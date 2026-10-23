# Branch Protection on `main` — Proposal

> **Status:** 📝 **PROPOSAL — NOT APPLIED** — awaiting Product Owner approval (§8).
> **Task:** OPS-8 / [#86](https://github.com/y0n1/bust_a_move_clone/issues/86) · **Owner:** DevOps Engineer · **Verified:** 2026-10-23 · **HEAD:** `2348c17`
> **Companions:** [`deployment.md`](deployment.md), [`deployment-log.md`](deployment-log.md), [`../agent-team.md`](../agent-team.md)

## 1. Current state — verified

Classic branch protection is **absent**. An **active ruleset** already blocks
force-push and deletion, but **direct fast-forward pushes to `main` are allowed**
and there is no PR or CI gate.

```console
$ gh api repos/y0n1/bust_a_move_clone/branches/main/protection
{"message":"Branch not protected","status":"404"}
gh: Branch not protected (HTTP 404)

$ gh api repos/y0n1/bust_a_move_clone/rulesets
[{"id":24729086,"name":"Default","target":"branch","enforcement":"active",
  "created_at":"2026-10-08T17:16:48.308+03:00"}]

$ gh api repos/y0n1/bust_a_move_clone/rules/branches/main
[{"type":"deletion","ruleset_id":24729086},
 {"type":"non_fast_forward","ruleset_id":24729086}]
```

Ruleset `Default`: targets `~DEFAULT_BRANCH`; rules are `deletion` +
`non_fast_forward` only; one `RepositoryRole` bypass actor (`actor_id: 5`,
`bypass_mode: "always"`); `current_user_can_bypass: "always"`.

### 1.1 Merge settings & merge history — PR-based by convention, not enforcement

```console
$ gh api repos/y0n1/bust_a_move_clone --jq '{default_branch, allow_merge_commit, ...}'
{"allow_merge_commit":true,"allow_rebase_merge":true,"allow_squash_merge":true,
 "default_branch":"main","delete_branch_on_merge":true}

$ gh pr list --state merged --limit 5 --json number,title,mergedAt
63  2026-10-23T01:52:52Z  docs: add DevOps and Quality Engineer agents...
62  2026-10-23T01:06:45Z  refactor: MVVM architecture...
59  2026-10-08T13:50:19Z  subtask: document architecture...
53  2026-10-08T12:48:04Z  docs: consolidate project board reference
50  2026-10-08T10:41:56Z  ci: remove pull_request trigger from deploy-pages

$ git ls-remote --heads origin
2348c17 refs/heads/main · b60af55 docs/agent-team-qe-devops · bbf937c docs/backlog-board-links
```

`delete_branch_on_merge` deletes **head** branches after a PR merge, never `main`.

### 1.2 Summary

| Control | State today | Evidence |
|---------|-------------|----------|
| Require pull request before merge | ❌ off | 404; no `pull_request` rule |
| Required status checks | ❌ off | `rules/branches/main` lists 2 rule types only |
| Required approvals / stale-approval dismissal | ❌ off | no `required_pull_request_reviews` |
| Require conversation resolution | ❌ off | no rule |
| Require branch up to date | ❌ off | no rule |
| Block force pushes | ✅ **on** | `non_fast_forward` |
| Block branch deletion | ✅ **on** | `deletion` |
| Apply to admins | ❌ no | `bypass_actors` = `always` |
| Direct push to `main` | ⚠️ **allowed** | rules do not restrict fast-forward pushes |

## 2. Why it matters here

`deploy-pages.yml` triggers on **`push` to `main` with no path filter**
(`on: push: branches: [main]`), so:

```mermaid
flowchart LR
    A[Direct push to main] --> B[push event] --> C[build web release]
    C --> D[deploy-pages@v4] --> E[PLAYER-FACING PRODUCTION]
```

No PR, no CI run, no `analyze-test`, no QE verdict — `ci.yml` only listens on
`pull_request`. A typo or a red test reaches players in one command. The ruleset
blocks *history-rewriting* accidents (force-push, deletion), not *quality* ones.

## 3. Proposed policy

| Setting | Proposed value | Justification |
|---------|----------------|---------------|
| Require pull request before merging | ✅ on | Every change to `main` gets a PR, a CI run, and a reviewable diff. |
| Required approvals | **0** | Solo-maintainer repo — GitHub forbids self-approval, so `1` would deadlock every PR. Revisit when a second collaborator exists. |
| Dismiss stale approvals | ✅ on | Cheap now, correct the moment approvals become non-zero. |
| Require status checks — `analyze-test` | ✅ on (strict/up-to-date) | Exactly one CI job exists: `analyze-test` in `ci.yml` (verified check-run `name`: `analyze-test`; `gh pr checks` renders it `CI/analyze-test`). It runs `flutter analyze --fatal-infos` + `flutter test test/`. |
| Require branches to be up to date | ✅ on | Deploy builds the *merge result*; green CI on a stale base proves nothing. Cost is low with ~1 open PR. |
| Require conversation resolution | ✅ on | Prevents merging with an unanswered QE/review objection. |
| Block force pushes | ✅ keep on | Already enforced by ruleset `Default`; restating it keeps one authoritative config. |
| Block deletions | ✅ keep on | Already enforced; `main` must never disappear. |
| Apply to admins | ✅ on (`enforce_admins`) | The current ruleset lets the owner bypass everything. Caveat: this only governs classic protection — the ruleset bypass actor survives it (§4.2). |

> **Note:** classic protection and rulesets are **additive** — the effective
> rule set is their union. Nothing proposed here weakens the existing ruleset.

## 4. Commands to apply — ⛔ NOT EXECUTED

> **Requires explicit Product Owner approval.** DevOps is not authorised to change repository settings.

### 4.1 Enable protection

```bash
gh api --method PUT repos/y0n1/bust_a_move_clone/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["analyze-test"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "dismiss_stale_reviews": true,
                                     "required_approving_review_count": 0 },
  "restrictions": null, "required_conversation_resolution": true,
  "allow_force_pushes": false, "allow_deletions": false
}
JSON
```

### 4.2 Optional hardening — remove the ruleset bypass (separate approval)

```bash
gh api --method PUT repos/y0n1/bust_a_move_clone/rulesets/24729086 \
  --input - <<'JSON'
{ "bypass_actors": [] }
JSON
```

Without this, the owner can still bypass `deletion` / `non_fast_forward` via the
ruleset even with `enforce_admins: true` — which is why it is a separate decision.

## 5. Rollback

```bash
# Inspect what is applied
gh api repos/y0n1/bust_a_move_clone/branches/main/protection

# Remove classic protection — ruleset Default stays, still blocking force-push/deletion
gh api --method DELETE repos/y0n1/bust_a_move_clone/branches/main/protection

# Restore the ruleset bypass if §4.2 was applied
gh api --method PUT repos/y0n1/bust_a_move_clone/rulesets/24729086 \
  --input - <<'JSON'
{ "bypass_actors": [{ "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }] }
JSON
```

Rollback is instant and leaves the pre-existing ruleset intact. If production is
involved, log it in `deployment-log.md` with a `ROLLBACK:` prefix.

## 6. Impact & trade-offs

| Area | Impact |
|------|--------|
| **Direct pushes to `main`** | No longer possible — including the Product Owner's. Docs-only and hotfix commits must go through a PR. |
| **Hotfix latency** | +1 PR + ~40 s CI (measured on PR #91). Emergency path: §5 rollback, then re-enable. Prefer a forward revert (see `deployment.md` §7). |
| **PR #91 flow** | **Already compliant** — branch `docs/backlog-board-links`, `analyze-test` green, mergeable. Adopting protection is near-zero friction. |
| **Deploy workflow** | **Unaffected.** A PR merge is still a `push` to `main`, so `deploy-pages.yml` fires exactly as today. Protection gates *how* commits arrive, not the resulting push event. |
| **Automation / bots** | No workflow currently pushes to `main` (deploy is read-only: `contents: read`), so nothing breaks. A future bot that pushes to `main` would need a bypass actor. |
| **Solo maintainer** | 0 required approvals keeps the workflow unblocked; `enforce_admins: true` still prevents self-bypass of CI. |
| **Strict up-to-date** | Each merge invalidates other open PRs. Acceptable at current concurrency (1 open PR). |

## 7. Verification after applying

| Check | Command | Expected |
|-------|---------|----------|
| Protection exists | `gh api repos/y0n1/bust_a_move_clone/branches/main/protection` | `200` with the §4.1 payload (no longer `404`) |
| Ruleset intact | `gh api repos/y0n1/bust_a_move_clone/rules/branches/main` | `deletion` + `non_fast_forward` + new protection rules |
| Check name matches CI | `gh pr checks <n>` | `analyze-test` shown as required/blocking |
| PR gate blocks red CI | Push a failing commit to a scratch branch, open PR | Merge button disabled until `analyze-test` passes |
| Direct push rejected | From a throwaway clone: commit an empty change on `main` and `git push origin main` | `remote: error: GH006: Protected branch update failed` — nothing lands, since the ref update is refused. **Requires approval to run; `--dry-run` is not a valid test** (no ref update is attempted, so the server may report success). |
| Admin bypass closed | `gh api repos/y0n1/bust_a_move_clone/rulesets/24729086 --jq .current_user_can_bypass` | `"never"` only if §4.2 is applied; otherwise `"always"` |

## 8. Decision required

This document is a **proposal**. **Nothing has been applied** — no protection
rule, no ruleset change, no repository setting; the §4 commands were deliberately
not executed.

**Ask:** approve §4.1 (and optionally §4.2). DevOps then applies them, runs the
§7 verification, and records the outcome here and in [`deployment-log.md`](deployment-log.md).
