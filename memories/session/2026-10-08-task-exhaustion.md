# 2026-10-08 Session — Task Exhaustion (Tasks 25, 23)

## Tasks Completed

### Task 25: Encapsulate _shotsTaken as level-scoped state
- **PR**: #37 (merged)
- **Changes**: Moved `shotsTaken` from Engine field to GameState snapshot
- **Files**: model.dart, engine.dart, descent_test.dart, engine_test.dart
- **Root cause of initial failures**: 4 GameState constructions in tests missing `shotsTaken: 0` parameter
- **Verification**: 31 tests pass, 0 analyze issues

### Task 23: Optimize _snapToHex O(n) → O(1) inverse hex lookup
- **PR**: #38 (merged)
- **Changes**: Replaced brute-force scan with inverse centerOf formula + 6-neighbor check
- **Edge case**: Projectile placed between row centers (y = ty + 0.51) rounds to wrong row by pure math; neighbor check resolves this
- **Performance**: 7 cells max vs 72 cells for 9×9 board
- **Verification**: 31 tests pass, 0 analyze issues

## Board Status
All tasks on project #3 are now Done. No remaining Ready tasks.

## Notes
- Task 23 required neighbor-check fallback — pure inverse math is insufficient for projectiles between row centers
- `descentSlack` doc updated to remove O(n) reference
- All PRs merged via squash, branches deleted
