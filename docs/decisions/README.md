# Decision Log

Architecture and product decisions live here as numbered ADRs (Architecture
Decision Records). The team uses them to stop re-litigating settled questions.

## Rules

- One decision per file: `NNNN-<slug>.md` (e.g., `0001-daily-challenge-seeds.md`).
- Number sequentially; never reuse a number.
- Status: `proposed` → `accepted` → `superseded` (link the superseding ADR).
- A decision needs a named owner and a date.
- Maximum **three** options, including "do nothing".
- If a debate exceeds its timebox, the accountable role decides and records it.
- Revisit only with new evidence; note the trigger in the ADR.

## Template

```markdown
# NNNN — Title

- **Status:** proposed | accepted | superseded by NNNN
- **Date:** YYYY-MM-DD
- **Owners:**
- **Deciders:**
- **Related:** brief / spec / issue / PR

## Context
What problem are we solving? What constraints apply?

## Options considered
1. **Option A** — description, pros, cons.
2. **Option B** — description, pros, cons.
3. **Do nothing** — description, pros, cons.

## Decision
What we chose and why. State the confidence level.

## Consequences
Positive, negative, and follow-up work.

## Revisit trigger
What new evidence would reopen this decision?
```

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| — | No decisions recorded yet | — | — |
