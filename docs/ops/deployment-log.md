# Deployment Log — Bust-A-Move Clone

> **Owner:** DevOps Engineer  
> Every production deployment gets one row. No row = no verified deployment.

---

## Log

| Date (UTC) | Version | Commit | Workflow run | Deploy | Production verification | Verified by | Notes |
|------------|---------|--------|--------------|--------|-------------------------|-------------|-------|
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
