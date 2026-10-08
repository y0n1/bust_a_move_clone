# Session 2026-10-08 — Architecture Refactor

## Completed
- ✅ Studied Flutter App Architecture Guide principles
- ✅ Created project board task (issue created on GitHub Project #3)
- ✅ Created `docs/architecture-plan.md` with full architecture plan
- ✅ Updated `AGENTS.md` to reference architecture-plan.md
- ✅ Created `memories/repo/project-board.md` with board info

## Architecture Decisions
- **Pattern**: MVVM — View → ViewModel → Model
- **Folder structure**: `lib/gameplay/` (feature), `lib/start_screen/` (feature)
- **State management**: `setState` + ViewModel (no Riverpod yet)
- **Domain layer**: Stays as-is (`lib/game/`) — pure Dart, immutable

## Migration Phases
1. Architecture plan ✅
2. Scaffold folders
3. Migrate domain (no changes)
4. Migrate UI
5. Migrate start screen
6. Tests

## Pending
- Phase 2: Scaffold feature folders and ViewModel skeletons
- Phase 3-6: Migrate code and add tests
