# Bug Regression Template — Bust-A-Move Clone

> **Owner:** Quality Engineer · **Task:** QE-10 / issue #78
> **Companions:** [`test-strategy.md`](test-strategy.md), [`release-checklist.md`](release-checklist.md), [`reports/2026-10-23-v1.0.0-baseline.md`](reports/2026-10-23-v1.0.0-baseline.md)

## 1. Purpose

Every confirmed bug gets a test that **fails before the fix and passes after it**. A
bug is not "fixed" because the symptom vanished once on one machine — it is fixed when
a test that reproduced it is green in `flutter test test/`. A fix PR without a
regression test is rejected at review, whatever its severity.

**The QE rejection loop.** When QE finds a bug in a shipped change, it does not
"reopen" anything: it attaches the evidence to the task, files the defect here,
moves the task back to **`Ready`**, and notifies the PM. The PM re-prioritises
(usually **P0**) and schedules a developer immediately. Nothing else moves a task
backwards, and nothing sends it anywhere but `Ready`.

## 2. Issue template

Copy verbatim into the GitHub issue body. Replace every `___`.

```markdown
## Bug: <short imperative title>

**Severity:** Critical | High | Medium | Low
<!-- Severity is QE's scale and is NOT board priority (P0-P2, owned by the PM).
     Critical = unplayable/blank page/crash/data loss/production down
     High     = core loop broken (match, pop, descent, win/lose, lives, restart)
     Medium   = degraded but playable with a workaround
     Low      = cosmetic/minor -->

### Environment
| Field | Value |
|-------|-------|
| Build version (`version.json`: `version`+`build_number`) | ___ (e.g. `1.0.0+1`) |
| Deployed commit / Actions run | ___ |
| Where | production `https://y0n1.github.io/bust_a_move_clone/` / local `build/web` / `flutter run` |
| Browser + version | ___ |
| OS + device | ___ |
| Viewport (WxH) + DPR | ___ |
| Input | mouse / touch / keyboard |

### Steps to reproduce
1. ___
2. ___
3. ___

### Expected
___

### Actual
___

### Reproducibility
- [ ] Always (___/___ attempts)
- [ ] Intermittent, rate ___% (___/___ attempts)
- [ ] Once

### Evidence
- Screenshot / recording: ___
- Console errors: ___
- Network failures (404s, service worker): ___

### Suspected subsystem
- [ ] `lib/game/engine.dart` — geometry, collision, match, drop, descent, status
- [ ] `lib/game/model.dart` — `GameState`, `Bubble`, `Projectile`, `LevelConfig`
- [ ] `lib/gameplay/viewmodel/game_viewmodel.dart` — aim, fire, ticker, layout, restart
- [ ] `lib/gameplay/ui/` — `game_screen.dart`, HUD, renderer
- [ ] `lib/start_screen/` — title, PLAY, navigation
- [ ] Build/deploy (`web/`, `.github/workflows/`) — not a code bug; hand to DevOps

### Regression test to add
- **File:** `test/engine_test.dart` | `test/descent_test.dart` | `test/gameplay/viewmodel/game_viewmodel_test.dart` | `test/start_screen_test.dart` | new file ___
- **Setup:** seed ___, `cols` ___, `rows` ___, `activeColorCount` ___, `descentInterval` ___, level ___
- **Action:** ___
- **Asserts:** ___ (exact `expect` on `status` / `bubbleRow` / `score` / `lives` / `bubbles.length` / widget finder)
- **Fails before fix because:** ___

### Fix verification
- [ ] Regression test fails on the unfixed commit and passes after the fix
- [ ] `flutter test test/` green (no other test regressed)
- [ ] `flutter analyze --fatal-infos` clean
- [ ] Manually re-ran the original steps on the built artifact
- [ ] QE verdict recorded in `docs/quality/reports/`
```

## 3. Fail-first workflow

Run in order; a test that fails for the wrong reason proves nothing.

```bash
curl -s https://y0n1.github.io/bust_a_move_clone/version.json   # 1. reproduce, capture version
flutter test test/descent_test.dart                            # 2+3. write the test, confirm it FAILS
# 4. developer fixes lib/ (not QE)
flutter test test/descent_test.dart                            # 5. confirm it PASSES
flutter test test/ && flutter analyze --fatal-infos            # 6. nothing else regressed
```

**Right reason vs. wrong reason.** A valid fail-first run shows the *assertion* from
the issue failing (e.g. `Expected: <playing> Actual: <lost>`) — not a compile error,
missing import, test typo, or `null` from a mis-built fixture. A test that fails both
before and after the fix is broken; rewrite it. Add `reason:` to non-obvious `expect`s.

**Where the test goes.** Engine rules → `test/engine_test.dart` or
`test/descent_test.dart` (pure Dart, `math.Random(seed)`, no Flutter). ViewModel →
`test/gameplay/viewmodel/game_viewmodel_test.dart`. Start screen →
`test/start_screen_test.dart`. Gameplay widgets → `test/gameplay/ui/`, which exists
but is **empty**: the first gameplay widget regression creates the file.

## 4. Determinism requirements

`lib/game/engine.dart` is pure Dart and seeded, so a repro is only real if it replays
from numbers. Capture **all** of these:

1. **Seed** — `math.Random(<seed>)` passed to `Engine(...)` or `Engine.forLevel(...)`.
2. **Board** — `cols`, `rows`, `activeColorCount`, `descentInterval`, `projectileSpeed`.
3. **Level + lives** — `engine.startLevel(initialLives: 3, level: 1)`.
4. **Shot sequence** — one angle in radians per shot, in order. `engine.shoot(s, angle)`:
   `0` is straight up, positive rotates clockwise toward the right, clamped by the
   ViewModel to ±60° (`math.pi / 3`). Record ticks per shot too.
5. **Observable outcome** — the exact `GameStatus`, `bubbleRow`, `score`, `lives`, and
   `bubbles.length` you saw.

`Engine.rng` is consumed by `startLevel()` **and** by the palette refill inside
`shoot()`, so shot order and shot count are part of the seed. Reordering shots changes
the board.

**Worked example — issue-style repro:** *Seed `42`.
`Engine(cols: 9, rows: 8, projectileSpeed: 0.6, rng: math.Random(42),
activeColorCount: 4, descentInterval: 1)`, then `startLevel(initialLives: 3, level: 1)`
→ 34 bubbles (4 cluster rows: 9+8+9+8), `bubbleRow == 0`. Shot 1: `shoot(s, 0.0)`, then
`tick` until `projectile == null` (≤ 500 ticks). Expected `bubbleRow == 1`,
`status == playing`. Actual `bubbleRow == 0` — the wall never descended.*

**Same repro as a test** (matches the helpers already in `test/descent_test.dart`):

```dart
final engine = Engine(
  cols: 9,
  rows: 8,
  projectileSpeed: 0.6,
  rng: math.Random(42),
  activeColorCount: 4,
  descentInterval: 1,
);
var s = engine.startLevel(initialLives: 3, level: 1);
s = engine.shoot(s, 0.0);
var ticks = 0;
while (s.projectile != null && s.status == GameStatus.playing && ticks < 500) {
  s = engine.tick(s);
  ticks++;
}
expect(s.bubbleRow, 1, reason: 'wall should descend after the first shot');
expect(s.status, GameStatus.playing, reason: 'one shot must not end the game');
```

Useful real symbols: `engine.centerOf(row, col)` → `(double x, double y)` in board-space;
`engine.neighborsOf(row, col)` → `Set<(int, int)>`; the cannon is `(engine.cannonX,
engine.cannonY)`; bubbles are keyed by `Bubble.key` (`'$row:$col'`);
`GameState.copyWith(...)` builds fixtures; `GameStatus` is `playing | won | lost`. For UI
bugs drive `GameViewModel(engine)` via `computeLayout(Size)`, `updateAim(Offset, Size)`,
`fire()`, `restart()` — never call `Engine` from a widget test.

## 5. Severity → test tier

| Severity | Regression must be | File | Gates release |
|----------|--------------------|------|---------------|
| **Critical** — unplayable, blank page, crash, data loss, production down | Engine or ViewModel unit test **and** a smoke check once #69 lands | `test/engine_test.dart`, `test/descent_test.dart`, `test/gameplay/viewmodel/game_viewmodel_test.dart` | **Yes — blocks merge and release** |
| **High** — core loop broken: match/pop, chain, cluster drop, descent, win/lose, lives, restart | Engine or ViewModel unit test | same as above | **Yes — blocks release** |
| **Medium** — degraded but playable with a workaround | Widget test if visual/input, otherwise unit/ViewModel | `test/gameplay/ui/` (new file), `test/start_screen_test.dart` | Only with recorded user risk acceptance |
| **Low** — cosmetic/minor | Optional; add only if cheap and stable | nearest existing file | No |

No gameplay widget tests exist yet (`test/gameplay/ui/` and `test/gameplay/logic/` are
empty), so a Medium gameplay UI bug relies on manual verification until the first one
lands — say so in the issue rather than implying coverage.

## 6. Triage SLA

Realistic for one human plus agents. If a High defect will miss its window, say so
on the issue and record it as a known risk.

| Severity | Acknowledge | Fix | Regression test |
|----------|-------------|-----|-----------------|
| Critical | Same day | Mitigate/roll back immediately; root cause within 2 days | In the fix PR |
| High | 1 business day | 3 business days | In the fix PR |
| Medium | 3 business days | Next release or 2 weeks, whichever first | In the fix PR, or a linked follow-up |
| Low | At next planning | When cheap | Optional |

## 7. Known baseline gaps

From [`reports/2026-10-23-v1.0.0-baseline.md`](reports/2026-10-23-v1.0.0-baseline.md):
these bug classes **cannot be caught automatically today**, so each needs a manual step
in the issue's "Fix verification" checklist until the linked issue lands.

| Gap | Issue | What slips through |
|-----|-------|--------------------|
| No smoke/E2E against the built artifact | #69 | Blank page, broken base href, service-worker staleness, start→play navigation |
| No coverage threshold | #70 | Untested engine branches (score, combo, multi-pop) with no visible signal |
| No accessibility audit | #71 | Color-only bubble cues, missing semantics, focus and contrast failures |
| No performance trace / Lighthouse budget | #72 | Jank during pops, chains, descent; load-time regressions |
| No cross-browser evidence | #73 | Firefox/Safari/Edge and mobile-touch defects invisible to Chromium-only runs |

Consequence: a High defect filed against one of these areas must include a **manual
reproduction on the built artifact** in its evidence. A green `flutter test test/` is
not evidence for any of them.
