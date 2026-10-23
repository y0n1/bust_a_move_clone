# UX Spec: Bounce-preview aim guide (PB-03)

| Field | Value |
|-------|-------|
| **Status** | ready for dev (design artifact — not an implementation task) |
| **Owner** | UX Designer |
| **Task** | UX-2 / [#68](https://github.com/y0n1/bust_a_move_clone/issues/68) |
| **Product brief** | [`backlog.md`](../product/backlog.md) PB-03 — RICE 18.0 = (5×4×0.9)/1.0; [`competitive-analysis.md`](../product/competitive-analysis.md) §4 "Aim guide", §6.1 |
| **Board state** | Backlog at time of writing. Design before triage is permitted ([charter §14](../agent-team.md)); **no implementation until Ready.** |
| **Depends on** | [`design-system.md`](design-system.md) tokens. `lib/design/tokens.dart` does not exist yet — see Q2. |

## 1. Problem

The engine bounces; the player cannot see it. `Engine.tick` reflects at `x < 0` and
`x > cols` (`engine.dart` L311–L318), but the only aim affordance is a **fixed-length
straight dotted line**: `bubble_renderer.dart` L141–L168 draws from
`(engine.cannonX, engine.cannonY)` along `(sin θ, −cos θ)` for exactly `len = 3.5` board
units, `Color(0x66FFFFFF)`, `strokeWidth 2`, dashes of `0.15` units. It never reflects,
never shortens at an obstacle, and stops ~6 units short of the wall.

Concrete failure: on level 5 (`cannonY = 10`) the line ends at `y ≈ 6.5`, so a 45° bank
shot lands anywhere in a 4-cell-wide fan. The player either avoids the wall — the
reference game's central skill (CA §2: "you aim at a *landing cell* you cannot see
directly, often via a wall") — or takes it blind, and a wrong landing costs a row of
descent (`descentInterval` 1 on levels 1, 2, 4, 5), so one mispredicted bounce compounds
into a lost life. The line is also only **3.73:1** on `surfaceBase`, below 4.5:1.

## 2. Goal & non-goals

**Goal.** While aiming, show the real path — including wall reflections — and mark the
exact cell the bubble will occupy, so a bank shot becomes intentional.

**In scope.** Path from cannon to first collision with reflections; one terminal-cell
indicator; bounce-point markers; reveal/cell-change motion with a reduced-motion fallback.
**Non-goals.** Predicting pops, chains or drops; spin, curve, power-ups; any engine rule,
constant or tuning change; keyboard aim; sound/haptics. Full list in §12.
## 3. Player-facing behaviour

| # | State | Trigger | Player sees | Guide |
|---|-------|---------|-------------|-------|
| 1 | Idle | No pointer in playfield (`hasPointer == false`) | Board, HUD, cannon | Hidden |
| 2 | Aiming | `pointerDown` / `pointerMove` in playfield, `projectile == null`, `status == playing` | Guide from cannon to terminal ring | Visible, tracks at 0 ms |
| 3 | Firing | `fire()` → `projectile != null` | Projectile + trail; cannon recoil | **Hidden instantly** (0 ms) — the shot is committed |
| 4 | Settled | `_onTick` sees `projectile` go null, `_hasPointer` still true | Board one row lower (descent is instant) | Recomputes against the **new** board at the **unchanged** `_aimAngle` |
| 5 | Won / lost | `status != playing` | Scrim + overlay | Hidden |
| 6 | Paused | Does not exist — `GameStatus` has no `paused` (design-system Q3, PB-07) | — | No behaviour to spec yet |
| 7 | Pointer leaves playfield | `MouseRegion.onExit` → `clearAim()` | Line and guide fade out | Fade `fast` 120 ms (Q4) |

**Edge cases.**

1. **Straight up (`angle == 0`).** One leg, no bounce. Note the honest asymmetry: `cannonX = 4.5`, and `_snapToHex` uses `x.round()` (half away from zero), so a vertical shot resolves to **col 5** on an even row and **col 4** on an odd row. The guide must show this, not a symmetric "centre column".
2. **Into a corner (`|angle| → 60°`).** One or two bounce markers; the reflected leg continues. Markers are inset (see §5) so they are never clipped by the canvas edge — `computeLayout` sets `offsetX = 0` in portrait, so the board touches the canvas.
3. **Path blocked early.** The guide simply ends where the projectile would hit: short, one leg, no bounce. This is the common case and must not look broken.
4. **Ceiling.** The engine settles at `p.y <= 0.5` (`_hitsBubbleOrWall` L329) but snaps with `row = (y / 0.866).round()` (`_snapToHex` L589), so a ceiling hit can resolve to **row 1** when row 1 is free. The ring must show the real row, never a presumed row 0.
5. **Board full / no free cell.** `_nearestFreeCell` returns the occupied `preferred` cell. The ViewModel downgrades this to `noLanding`: **no ring**, keep the fallback line. Never draw a ring on an occupied cell.
6. **Bounce cap exceeded.** Cannot happen (§4); if it does, truncate and show **no ring** rather than a guess. Only a settle or a restart changes `bubbles`; both recompute.

## 4. The prediction contract

**Definition.** *Settled cell* = the `(row, col)` produced by `_settleShot`
(`engine.dart` L344) → `_snapToHex` (L585), or `_nearestFreeCell` (L354) when that cell
is occupied.

**The contract.** `aimGuide.path.terminalRow/terminalCol` **must equal the settled cell**.
Not adjacent, not nearest — equal. Any other outcome is a bug, not a tolerance.

**What must be mirrored exactly** (each of these is a real drift source):

| # | Engine behaviour | Where | Consequence of getting it wrong |
|---|------------------|-------|---------------------------------|
| 1 | Start `(cols/2, rows+1)` | L147–148 | — |
| 2 | `vx = sin θ · v`, `vy = −cos θ · v`, `v = projectileSpeed` | L~286 | Mirrored direction |
| 3 | **8 substeps of `advance(projectileSpeed / 8)`** | L303–305 | Per-tick travel is **`v²`, not `v`** (level 1: 0.36, not 0.6). A guide stepping `v` per tick overshoots ~2.8× and lands rows late. `design-system.md` §4 row 4 states `v`; that figure is wrong. |
| 4 | Per substep, in order: advance → `y <= 0` ⇒ wasted → clamp `x` to `[0, cols]`, negate `vx` → collision ⇒ settle | L305–320 | Wrong wall position, wrong leg count |
| 5 | Collision: `y <= 0.5` **or** squared distance to any bubble `<= 0.9` (forgiving) | L327–L335 | Shot stops ~0.05 units early; the snap depends on it |
| 6 | Snap: `row = (y/0.866).round()`, `col = (x − (row.isOdd ? 0.5 : 0)).round()`, clamp, then nearest of candidate + 6 `neighborsOf` | L585–L612 | Off-by-one cells |
| 7 | Occupied ⇒ BFS `_nearestFreeCell` | L354–L372 | Ring on an occupied cell |

Iteration order of `s.bubbles` does **not** affect the cell: `_hitsBubbleOrWall` returns
`true` for *any* hit and the settle uses the projectile's position, not the bubble's.

**How many bounces: 2 — and it is not a product choice, it is the maximum.**Aim is clamped to `±π/3` (`updateAim`, `game_viewmodel.dart` L190). Vertical travel from
`cannonY = rows+1` to the ceiling band `y = 0.5` is `rows + 0.5 ≤ 9.5`; maximum horizontal
travel is `9.5 · tan 60° = 16.45`. The `x` range is `[0, cols]`, width 9, starting at
`x = 4.5`: the first wall is ≤ 4.5 away, then each crossing is 9 wide, and
`4.5 + 9 + 9 = 22.5 > 16.45`. **No legal shot reaches the ceiling after more than 2 wall
hits**, so the march always terminates on a real collision. The cap is a safety valve.

**When the path exceeds the cap** (defensive only): draw the legs computed so far, end the
last leg with no marker, and draw **no terminal ring**. An unmarked path is honest; a
wrong ring is not.

**Accuracy acceptance criterion (verbatim):**

> **AC-1** — For 200 seeded angles on a fixed board, predicted terminal cell == actual settled cell, 100%.

**Harness note** (makes the settled cell observable). Use `Engine.forLevel(3,
rng: math.Random(42))`: level 3 has `descentInterval == 2`, so one shot from
`shotsTaken == 0` does **not** descend and the new bubble keeps its key. Recolour every
bubble to `BubbleColor.red` via `copyWith` and force `nextColors` to a non-red colour, so
no shot can pop and the settled cell is the only key added to `bubbles`.

## 5. Visual spec

All values in screen space unless marked *board units* (× `bubbleSize`); geometry from
`boardToScreen(x, y, size)` = `(x·bubbleSize + offsetX, y·bubbleSize + offsetY)`.

| Element | Geometry | Paint |
|---------|----------|-------|
| **Path legs** | Polyline cannon → wall hits → impact, clipped at the terminal ring's radius | `AppColors.aimLine` (`0x99FFFFFF`), `strokeWidth 2`, `StrokeCap.round`, dash 0.15 on / 0.15 off *board units* (today's cadence, so the guide reads as the same visual language) |
| **Leg alpha** | Leg 0 = 100% of the token; leg 1 = 80%; leg 2 = 67% | Effective `0x99` / `0x7A` / `0x66` white → **6.70:1 / 4.77:1 / 3.72:1** on `surfaceBase`. All ≥ 3:1. No new colour values — multipliers on the token's alpha only |
| **Bounce marker** | Filled circle, radius `0.10 × bubbleSize`, centre at the wall-hit point **inset `0.10` board units inward** (never clipped at `offsetX == 0`) | `AppColors.aimLine` at the leg's alpha, `BlendMode.srcOver`, no blur |
| **Terminal ring** | Hollow circle at `engine.centerOf(row, col)`, radius `0.44 × bubbleSize` (real bubbles are `0.48`), **no fill**, dashed 4 dp on / 4 dp off, `StrokeCap.butt`. Never a bubble colour, fill, highlight, `bubbleRim` stroke or `BubblePalette` symbol | `AppColors.aimLine` at **100% alpha always** — the path recedes across bounces, the destination does not |

**Compositing.** Insert `aim guide` into the fixed z-order (`design-system.md` §5.4)
**immediately after `progress bar`, before `bubbles`** — the board occludes the guide, as
deference requires. Within the guide: legs → markers → ring. No `saveLayer`, no blur.

**The guide replaces the aim line.** When a resolved guide exists, draw the guide only —
leg 0 *is* the aim line, so drawing both would show a seam. Otherwise fall back to today's
3.5-unit straight line, promoted from `0x66FFFFFF` to `AppColors.aimLine`.

## 6. Motion & reduced motion

| Element | Trigger | Duration | Easing | Reduced-motion fallback |
|---------|---------|----------|--------|-------------------------|
| Guide reveal (all parts) | `hasPointer` false → true | `AppMotion.fast` 120 ms, opacity 0 → 1 | `AppMotion.enter` | Instant, same alpha |
| Guide track | `pointerMove` | **0 ms** — direct manipulation | — | Unchanged |
| Terminal ring, cell changed | `(row, col)` differs from the previous frame | `AppMotion.fast` 120 ms, scale 0.86 → 1.00, opacity 0.6 → 1.0 | `AppMotion.emphasis` | Opacity only, no scale |
| Bounce marker appear | Leg count grew | `AppMotion.fast` 120 ms fade | `AppMotion.enter` | Instant |
| Guide dismiss | `fire()` | **0 ms** | — | Unchanged |
| Guide dismiss | Pointer leaves playfield | `AppMotion.fast` 120 ms fade | `AppMotion.exit` | Instant |

The **polyline never lags the pointer** — only the ring's appearance animates, and the old
ring is removed instantly (no trail of stale rings). Nothing loops while idle
(`design-system.md` principle 4), so the ring does **not** pulse. Reduced motion still
*shows* the guide (information, not decoration) but drops its transitions. **Do not drive
this from `_fxElapsedMs`** — it accumulates cumulative elapsed each tick
(`game_viewmodel.dart` L165) and drifts quadratically; use the Ticker's `elapsed` (Q3).

## 7. Accessibility

1. **Colour-blind safety (SC 1.4.1).** The guide uses **no hue at all** — one neutral white token, one filled dot, one hollow dashed ring. It is identical in all CVD types. Bubble colour is never consulted, so `BubblePalette` symbols are not needed here.
2. **Contrast (SC 1.4.11 ≥ 3:1).** 6.70:1 / 4.77:1 / 3.72:1 by leg; ring and markers 6.70:1. Passes on `surfaceBase`.
3. **Ring vs real bubble.** Distinguished by **form**, four ways at once: hollow (real bubbles are filled), dashed (real rims are solid 1 dp), 8% smaller radius, and no symbol/highlight. It is also always drawn on an *empty* cell — enforced by AC-7.
4. **Pointer vs touch.** Hover shows the guide before commit, so the player can sweep and read. Touch has no hover: the guide appears on `pointerDown` and updates through `pointerMove`; `pointerUp` still fires — **no new confirm step**. The finger covers the cannon, not the landing cell several rows up, and offsetting the guide is forbidden (that would be a lie).
5. **Screen reader.** The playfield node gains `Semantics(value: 'Landing row R, column C')`, updated **only when the cell changes**, `liveRegion: false`. The board's existing summary label is unchanged.
6. **Keyboard.** No keyboard aim exists today (`design-system.md` §6.4 proposes ←/→ ±3°). When it lands, the guide follows each discrete step with no animation. Not in PB-03.
7. **Text scaling / small screens.** The guide is geometry, not text; it scales with `bubbleSize` (clamped 32–120), so it is unaffected by `textScaler`.
## 8. State & data model

Prediction is **ViewModel state, never View state** — Views do not call `Engine`.

```dart
// lib/game/model.dart — additive value types. Pure Dart: doubles and ints only.
enum AimPathStatus { resolved, noLanding, exceededBounceCap }
/// One straight leg of a predicted shot, in board-space bubble diameters.
class AimLeg {
  const AimLeg({required this.fromX, required this.fromY,
                required this.toX, required this.toY, required this.bounces});
  final double fromX, fromY, toX, toY;
  final int bounces; // 0 before the first wall hit, 1 after it, 2 after the second
}
/// Read-only result of predicting a shot. Never mutates GameState.
class AimPath {
  const AimPath({required this.legs, required this.terminalRow,
                 required this.terminalCol, required this.status});
  final List<AimLeg> legs;   // 1..3
  final int terminalRow;     // -1 when status != resolved
  final int terminalCol;     // -1 when status != resolved
  final AimPathStatus status;
}
// lib/game/engine.dart — ADDITIVE, READ-ONLY. Reuses the private _snapToHex,
// _hitsBubbleOrWall and the same 8-substep march, so there is ONE physics
// implementation. Consumes no rng. Mutates nothing.
AimPath predictAim(GameState s, double angle, {int maxBounces = 2});
// lib/gameplay/ui/renderer/bubble_renderer.dart — presentation, next to ScorePopup.
class AimGuide {
  const AimGuide({required this.path, required this.opacity, required this.ringScale});
  final AimPath path;
  final double opacity;   // 0..1 reveal fade
  final double ringScale; // 0.86..1.00 cell-change emphasis
}
// GamePainter gains one field:
final AimGuide? aimGuide; // null = draw the fallback straight line only

// lib/gameplay/viewmodel/game_viewmodel.dart — additive members.
AimGuide? _aimGuide;
int _aimRevealStartedMs = -1; // Ticker elapsed ms at reveal; -1 = not revealing

AimGuide? get aimGuide => _aimGuide;

void _refreshAimPreview();  // private: predict, downgrade occupied cells to
                            // noLanding, build AimGuide, detect cell change
void clearAim();            // public: _hasPointer = false; _aimGuide = null;
                            // _aimRevealStartedMs = -1; notifyListeners()
```

Call sites: `updateAim` calls `_refreshAimPreview()` after clamping; `fire()` sets
`_aimGuide = null`; `_onTick` calls `_refreshAimPreview()` once on `settled &&
_hasPointer`. `restart()` clears all three. No `GameState` change.

## 9. Performance budget

| Item | Budget |
|------|--------|
| Recompute frequency | Pointer moves + one per settle. **Never per tick** |
| March length | ≤ 21 ticks × 8 substeps = 168 positions (level 5: `10 / 0.7²`) |
| Collision tests | ≤ 27 bubbles per substep (3 rows × 9 cols within `±1` of `p.y`), ≈ 4.5 k total. **Never all 81.** Snap: ≤ 7 cells per prediction |
| Allocation | ≤ 4 small objects per pointer move (one `AimPath`, ≤ 3 `AimLeg`). **No `GameState`, no `Map`, no `List` growth, nothing inside the substep loop.** Steady-state zero when the cell is unchanged and opacity is settled |
| Drawing | 3 `Path` objects (one per leg) with dash segments as `moveTo`/`lineTo`; no `saveLayer`, no blur. Replaces today's ~12 `Path` objects per frame |
| Wall time | ≤ 0.25 ms per pointer move on a mid-range mobile browser (≤ 1.5% of a 16.7 ms frame) |

**What would make it too slow:** testing every bubble at every substep (3× worse); cloning
`GameState` and calling `engine.tick` (≈21 map copies per move, hundreds of KB/s of
garbage, **and** it burns `rng` in `_refill`, so the colour queue would depend on how much
the player wiggles the mouse — a determinism violation); recomputing every tick;
unbounded bounce count; a `MaskFilter` on the ring.

## 10. Acceptance criteria

- [ ] **AC-1** (accuracy, §4) → `test/engine_test.dart`
- [ ] **AC-2** Every bounce point satisfies `x == 0` or `x == cols` (±1e-9); `bounces` increments by exactly 1 per leg → `test/engine_test.dart`
- [ ] **AC-3** `predictAim` is pure: `bubbles`, `nextColors`, `score`, `shotsTaken` identical before/after; two calls on equal states return equal paths → `test/engine_test.dart`
- [ ] **AC-4** Over the same 200 angles, `status == resolved` in 200/200 (the cap is never hit) → `test/engine_test.dart`
- [ ] **AC-5** `updateAim` populates `vm.aimGuide` with a `resolved` path → `test/gameplay/viewmodel/game_viewmodel_test.dart`
- [ ] **AC-6** `aimGuide` is null while `projectile != null`, and when `status != playing` → same file
- [ ] **AC-7** Invariant: `vm.aimGuide!.path.terminalRow/Col` is always an **empty** cell in `vm.state.bubbles` → same file
- [ ] **AC-8** `fire()` clears `aimGuide`; `clearAim()` clears it and sets `hasPointer == false` → same file
- [ ] **AC-9** After a shot settles with the pointer still present, `aimGuide` is non-null and its cell is legal on the new board → same file
- [ ] **AC-10** Widget: guide absent before any pointer event; after a pointer move at 45° the `GamePainter`'s `aimGuide.path` matches `vm.aimGuide!.path`; absent when `status == lost` → `test/gameplay/ui/game_screen_aim_guide_test.dart` (**new file — `test/gameplay/ui/` exists and is empty**)
- [ ] **AC-11** Widget, reduced motion: with `MediaQueryData(disableAnimations: true)` the guide renders at `opacity == 1.0` on the first frame after the pointer move → same file
- [ ] **AC-12** No regressions: `flutter test test/` stays green (45 existing tests) and `flutter analyze --fatal-infos` is clean → whole suite + CI

## 11. Open questions

| # | Question | Needed from |
|---|----------|-------------|
| Q1 | Approve one **additive, read-only** `Engine.predictAim` (no rule, constant, or behaviour change; no RNG; no mutation). If "no engine edit at all" is imposed, the fallback duplicates `0.866`, `0.5`, `0.9`, `8` in the ViewModel — two physics implementations that must agree forever. | Product Owner + Engine Developer |
| Q2 | `lib/design/tokens.dart` does not exist. Does PB-03 land the token file first, or inline `0x99FFFFFF` with a TODO? (design-system Q1 — `lib/design/` ownership is unassigned.) | Product Owner |
| Q3 | `_fxElapsedMs` is a quadratic clock (`+= elapsed.inMilliseconds`, L165); score popups compare against it and never render. PB-03 needs a linear clock for the reveal. Fix it here, or use a separate linear field and file the bug separately? | Flutter Developer + PM |
| Q4 | Does `MouseRegion.onExit` → `clearAim()` belong in PB-03? It also changes today's aim line, which currently freezes at the last angle when the pointer leaves. | Product Owner |
| Q5 | Backlog §3.1 fallback: "if a one-bounce preview trivialises the game, cap it to 0.75 of the board." The documented fallback is to draw only the first `0.75 × rows` of travel and **drop the terminal ring**. Confirm this is the intended lever, and that full-path is the default. | Product Owner |
| Q6 | Should the ring carry the loaded bubble's `BubblePalette` symbol? I recommend **no** — restraint; the cannon and HUD `NEXT` already show it. | Product Owner |

## 12. Out of scope

1. **Full trajectory prediction** — pops, match groups, chains, detached drops. The guide predicts a *cell*, not an outcome.
2. **Spin, curve, wind, power-ups, special bubbles** (PB-11); **sound and haptics** (design-system Q5).
3. **Any engine rule change** — no constant, collision, snap, descent or scoring change.
4. **Aim assist** beyond the existing ±60° clamp; **keyboard aim** (design-system §6.4, separate task).
5. **A player-facing toggle** to disable the guide (needs a PM decision); **pause** (no `GameStatus.paused`, PB-07).

> **Engine-change callout — read this.** PB-03 **is** implementable without changing any
> engine *rule*: not one constant, branch or output changes. It needs exactly one
> **additive, read-only query** on `Engine`, because `_snapToHex`, `_hitsBubbleOrWall` and
> the 8-substep march are private and the alternative is a duplicated physics model in the
> UI layer. If the constraint is instead "do not touch `lib/game/engine.dart` at all",
> PB-03 is still achievable via public API (`cols`, `rows`, `cannonX`, `cannonY`,
> `projectileSpeed`, `centerOf`, `neighborsOf`) at the cost of duplicating four constants —
> **I recommend against it**; AC-1 would then be the only thing holding the two
> implementations together. Neither path changes a rule. **No finding blocks PB-03.**
