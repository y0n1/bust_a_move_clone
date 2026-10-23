# Deployment Log — Bust-A-Move Clone

> **Owner:** DevOps Engineer  
> Every production deployment gets one row. No row = no verified deployment.

---

## Log

| Date (UTC) | Version | Commit | Workflow run | Deploy | Production verification | Verified by | Notes |
|------------|---------|--------|--------------|--------|-------------------------|-------------|-------|
| 2026-10-23 15:21 | 1.0.0+1 | `6c21684` | [39977553584](https://github.com/y0n1/bust_a_move_clone/actions/runs/39977553584) | ✅ success | ✅ HTTP 200 in 0.50 s; `version.json` 1.0.0+1; critical-path smoke 10/10 on the `main` checkout; **tagged [`v1.0.0`](https://github.com/y0n1/bust_a_move_clone/releases/tag/v1.0.0)** | DevOps / QE | Merge of PR #92 (docs only). **First tagged release** — closes OPS-10 (#88); rollback target is now `v1.0.0`. Ships known defect #95 (icons as base64 text, one manifest icon 404); fixed on `develop` by PR #97. See [release gate](../quality/reports/2026-10-23-v1.0.0-release-gate.md). |
| 2026-10-23 02:41 | 1.0.0+1 | `09ebc70` | [39948828182](https://github.com/y0n1/bust_a_move_clone/actions/runs/39948828182) | ✅ success | ✅ HTTP 200 on index; `version.json` 1.0.0+1 | DevOps | Merge of PR #91 (docs only). App bundle unchanged. |
| 2026-10-23 01:52 | 1.0.0+1 | `2348c17` | [39886481923](https://github.com/y0n1/bust_a_move_clone/actions/runs/39886481923) | ✅ success | ✅ HTTP 200 (index, `version.json`, `flutter_bootstrap.js`); `version.json` 1.0.0+1; Flutter view mounted, page title `Bust A Move`; no console errors | DevOps | Merge of PR #63 (docs only — agent team, quality and ops artifacts). App bundle unchanged. Still no `v1.0.0` tag (OPS-10). |
| 2026-10-23 01:09 | 1.0.0+1 | `4b5d3fe` | [39882358617](https://github.com/y0n1/bust_a_move_clone/actions/runs/39882358617) | ✅ success | ✅ HTTP 200; `version.json` 1.0.0+1; start screen → PLAY → game screen; no console errors | DevOps baseline | No `v1.0.0` tag exists yet (OPS-10). |
| 2026-10-08 10:41 | pre-1.0 | `c642ea4` | [37765184137](https://github.com/y0n1/bust_a_move_clone/actions/runs/37765184137) | ✅ success | Not re-verified during baseline | — | Historical deploy. |
| 2026-10-08 10:27 | pre-1.0 | `8cab915` | [37763601369](https://github.com/y0n1/bust_a_move_clone/actions/runs/37763601369) | ✅ success | Not re-verified during baseline | — | Historical deploy. |

---

## Entry template

```markdown
| YYYY-MM-DD HH:MM | X.Y.Z+N | `abc1234` | [run-id](url) | ✅/❌ | ✅/❌ + evidence | Name | Notes |
```

### Generating the verification column

Since OPS-4, the `smoke` job in `deploy-pages.yml` runs
`test/quality/post_deploy_check.py` against the live URL on every deploy. On a
passing run the script prints a ready-to-paste row built from the evidence it
already measured:

```bash
python3 test/quality/post_deploy_check.py
```

The row is emitted only after every check passes — it cannot be produced from a
run that failed or did not happen. The run id, commit and deploy conclusion still
come from the workflow run; copy them from the job summary.

## Verification evidence to capture

- Deploy workflow conclusion and run URL.
- Deployed commit SHA and version/build number.
- `curl -I` status and response time for the production URL.
- `version.json` contents.
- Smoke-path result (start → aim → fire → match → retry).
- Browser console errors (none blocking).
- Rollback target (last known-good commit).

## Rollback entries

Prefix the note with `ROLLBACK:` and include the incident reference, the
restored commit, and the verification result.
