# Session: AGENTS.md restructuring + ICM research

**Date:** 2026-10-06

## What happened

1. Researched and consumed two reference documents:
   - Karpathy's LLM Wiki pattern (gist: 442a6bf555914893e9891c11519de94f) — compounding knowledge base via ingest/query/lint
   - Van Clief & McDermott's Interpretable Context Methodology (arXiv:2603.16021) — five-layer context hierarchy, folder structure as orchestration

2. Rewrote `AGENTS.md` from a Claude-code-specific document into a model-agnostic ICM Layer 0 schema:
   - Collapsed ICM layers 0–2 into one file with a navigation table
   - Mapped Karpathy's wiki pattern to `memories/` directory
   - Removed vendor lock-in (no Claude-specific references)

3. Reduced `CLAUDE.md` to `@AGENTS.md` — single canonical source, Claude Code auto-follows the reference.

## Key decisions

- ICM's Layer 2 stage contracts are deferred — this project is a game, not a multi-stage content pipeline
- Memory layer starts minimal: three directory scopes, lightweight operations (record short notes, check at session start, clean stale ones)
- `AGENTS.md` section 4 "What NOT to do" uses negative constraints (often more effective than positive ones for preventing regressions)

## Open questions (no answers yet)

- Do we need Layer 2 stage contracts if development stages emerge?
- How aggressive should the memory layer be for a small game project?
- AGENTS.md vs CLAUDE.md coexistence — decided: CLAUDE.md is now just `@AGENTS.md`

## Intake: HANDOVER.md (2026-10-06 ~15:20)

Previous session's handover document consumed and merged into `memories/repo/facts.md`. HANDOVER.md deleted after intake.

Key facts absorbed:
- Descent fix landed but needs in-browser verification (Bug #1)
- Death line mismatch: UI draws at `rows - 1`, engine loses at row `rows`
- `_nearestFreeCell` may reject valid cells after descent; `_snapToHex` scans `rows + 8`
- 5 open issues on Kanban (#1–#5)
- CDP harness: `tools/cdp.py` + `.venv/`, Chrome on DISPLAY=:1, CDP port 9322, web server at :8400
- Flutter at `/home/y0n1/.flutter/bin/flutter` (3.47.1)
- GitHub repo: `y0n1/bust_a_move_clone` (SSH)
- Agent artifacts: `.venv/`, `outputs/`, `current_session_context/`
