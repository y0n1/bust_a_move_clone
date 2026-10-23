# Deployment Log — Bust-A-Move Clone

> **Owner:** DevOps Engineer  
> Every production deployment gets one row. No row = no verified deployment.

---

## Log

| Date (UTC) | Version | Commit | Workflow run | Deploy | Production verification | Verified by | Notes |
|------------|---------|--------|--------------|--------|-------------------------|-------------|-------|
| 2026-10-23 01:09 | 1.0.0+1 | `4b5d3fe` | [39882358617](https://github.com/y0n1/bust_a_move_clone/actions/runs/39882358617) | ✅ success | ✅ HTTP 200; `version.json` 1.0.0+1; start screen → PLAY → game screen; no console errors | DevOps baseline | Last known good. No `v1.0.0` tag exists yet (OPS-10). |
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
