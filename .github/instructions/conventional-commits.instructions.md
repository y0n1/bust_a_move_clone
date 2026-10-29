---
description: "Use when creating git commits, staging changes, or writing/editing any commit message. Enforces Conventional Commits v1.0.0 and SemVer-derivable history per ADR 0001. Use when: commit, commit message, git commit, conventional commits, semantic commits, changelog, release version."
name: "Conventional Commit Messages"
---

# Conventional Commit Messages

Every commit message MUST follow Conventional Commits v1.0.0, per [ADR 0001](../docs/decisions/0001-gitflow-and-conventional-commits.md). The release version is derived from commit history — a wrong type produces a wrong release.

## Format

`<type>(<scope>)?: <description>` — imperative mood, lower-case, no trailing period, subject ≤ 72 chars. Body explains **why**, not what.

## Types → SemVer

| Type | Use for | SemVer |
|------|---------|--------|
| `feat` | New player-visible capability | MINOR |
| `fix` | Bug fix | PATCH |
| `perf` | Performance, no behavior change | PATCH |
| `refactor` | Restructuring, no behavior change | none |
| `docs` / `test` / `style` / `chore` / `ci` / `build` | Non-src changes | none |
| `revert` | Reverts a commit; reference the SHA | matches reverted |

- **Scope** (touched area): `engine`, `ui`, `hud`, `renderer`, `viewmodel`, `start`, `ci`, `docs`, `board`, `deps`.
- **Breaking change:** `!` before the colon **and** a `BREAKING CHANGE:` footer → MAJOR.
- **Footers:** `Refs: #N` or `Fixes: #N` to link the board task (`Fixes:` closes it).

## Examples

```text
feat(engine)!: hex-wrap traversal for the bottom wall

Rows now wrap left-to-right when a bubble reaches the side walls,
matching the arcade original.

BREAKING CHANGE: Engine.centerOf board-space coordinates shift by 0.5.
Refs: #42
```

```text
fix(renderer): stop score popups overlapping at high combo counts
Fixes: #87
```

```text
// ❌ BAD — no type, no scope, vague
Updated the game and fixed bugs

// ❌ BAD — feat on a refactor inflates MINOR
feat(ui): rename BubblePainter to GamePainter
```

## Guardrails

- Pick the type by the change's actual effect on players and version — never `feat` for internal-only changes.
- If the version derived from history wouldn't match intent, fix the commits — do not hand-edit the `pubspec.yaml` version to compensate.
