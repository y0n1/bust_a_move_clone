# Feature: Next-bubble queue beside the cannon

- **Status:** proposed (spike approved by Product Owner; production change not yet approved)
- **Owner:** Product Manager
- **Date:** 2026-10-29
- **Related issues:** [#42](https://github.com/y0n1/bust_a_move_clone/issues/42) (closed — the unfinished half of this), backlog **PB-13**, UX-1 / #67 (design system, In review)
- **Requested by:** Product Owner, 2026-10-29 — "move the balls stack next to the cannon"
- **Scope decided by the Product Owner:** throwaway spike first; decide after seeing it

## Problem

Two problems, one change.

1. **The loaded bubble is not visually bound to the cannon.** The player's most
   frequent question — "what am I about to fire?" — is answered by a widget in the
   **top-right HUD row**, several hundred dp away from the cannon at the
   **bottom-centre** of the canvas. #42 filed exactly this ("no visual distinction
   between the current loaded bubble and the upcoming ones", MEDIUM, confidence 9/10)
   and asked for a vertical stack "**positioned next to the cannon on the canvas
   (matching the original Bust-A-Move layout)**". What shipped was the *stack* and the
   *highlight* half, in the HUD row — see
   [`level_display.dart`](../../lib/gameplay/ui/hud/level_display.dart) (`NEXT` + 28 dp
   loaded bubble with arrow + two 18 dp previews, inside the top `Row`). The
   **placement half of #42 was never built**. This brief closes that gap.
2. **The compact top bar is overloaded.** At the 360 dp floor the `Row` in
   [`game_screen.dart`](../../lib/gameplay/ui/game_screen.dart) must seat `SCORE`
   (plus the reserved `COMBO` chip) · `LIVES` · `LEVEL` · `NEXT` + queue · restart icon
   in one 56 dp line. Summing the design-system token widths gives ≈ 410 dp of content
   in 336 dp of usable gutter. *(Inference from tokens, not a measurement — the spike
   must confirm it with a widget test at 360 × 640 asserting no `RenderFlex` overflow.)*
   The queue is the largest item in that row that does not need to be in the row at all.

## Evidence

| Claim | Type | Source |
|-------|------|--------|
| #42 requested this placement and it was not implemented | **Fact** | Issue #42 body vs. current `level_display.dart` |
| Queue lives in the HUD `Row`; the canvas draws only board/cannon/FX | **Fact** | `level_display.dart`; `bubble_renderer.dart` (`_drawCannon` at `boardToScreen(engine.cannonX, engine.cannonY)`, no queue) |
| Queue length is 3 (`nextColors[0]` loaded, `[1..2]` previews) | **Fact** | `engine.dart` L197; `model.dart` L128 |
| Cannon at `(cols/2, rows+1)`; deepest possible bubble row is `rows` at `y = rows × 0.866` | **Fact** | `engine.dart` L147, L223–232 |
| Layout box height is `rows + 1.2`, so only **0.2 bubble-diameters of clearance exist below the cannon** | **Fact** | `computeLayout`, `game_viewmodel.dart` L201–220 |
| The design system currently *specifies* the queue in the top-bar stats cluster and fixes z-order and preview counts | **Fact** | [`design-system.md`](../../docs/design/design-system.md) §5.1, §5.3, §5.4 |
| Previews are colour-only circles today; §6.2 requires six distinct silhouettes (`× ▲ ▬ ✦ ◆ ▪`) on the queue | **Fact** | `level_display.dart` vs. design-system §6.2 |
| The arcade original shows the next bubble near the cannon | **Assumption** — asserted in #42, **not** verified in [`competitive-analysis.md`](competitive-analysis.md), which records queue *discipline* (§4) but not queue *placement* | PM to close before any production task |
| Proximity removes the ambiguity #42 described | **Inference** | Gestalt proximity; untested by playtest |
| Freeing the queue relieves 360 dp overflow | **Inference** | Token arithmetic above; the spike must measure it |

## Target player

The **primary** segment in [vision §2](../vision.md) — a lapsed arcade player on a
phone browser or a narrow desktop window, mid-shot, deciding whether to spend the
colour they have been dealt. Their eyes are on the board and the cannon, not on the
top-right corner.

## User value

- **One less saccade per shot.** The colour you hold is read where the shot leaves
  from, which is where your eye already is (Pillar 2, *readable at a glance*).
- **The HUD row gets ≈ 90 dp back** at the 360 dp floor — the difference between a bar
  that fits and a bar that reflows.
- **Proximity makes "loaded" self-evident**, so the `Icons.arrow_forward_ios` glyph
  inside the 28 dp bubble — a crutch for distance — can go.

It is *not* a new mechanic: engine, rules, palette and queue logic are untouched. That
is what keeps this inside Pillar 1 rather than in tension with it.

## Proposed behavior

The queue is painted by `GamePainter` in the canvas layer, anchored beside the cannon
and outside the bubble-occupied band, instead of being a widget in the top HUD `Row`.

- Loaded bubble (28 dp, accent ring) sits **beside** the cannon at the cannon row;
  previews run away from the board edge (2 at compact, 3 medium+ — unchanged from
  §5.3).
- The top HUD row keeps `LIVES`, `LEVEL` and restart, and drops `NEXT` + queue.
- Nothing is tappable — the queue stays an indicator, so the 44 dp target rule (§6.1)
  does not apply.
- Debug flag `--dart-define=QUEUE_AT_CANNON=true` selects the new placement; the
  current placement stays the default until the Product Owner approves the switch.

**Core loop is unchanged:** aim → fire → pop → descend. The player still sees three
colours; they just see them where the shot happens.

## Acceptance criteria

Spike (throwaway, debug-flagged, not shipped):

- [ ] With the flag on, the queue renders in the canvas beside the cannon; with it off,
      the game is pixel-identical to `main`.
- [ ] Demoable at **360 × 640 on level 5+ (`rows = 9`) with the wall fully descended** —
      the case where descent bubbles come closest to the cannon. Screenshot on the issue.
- [ ] Engine untouched: `lib/game/` has zero diff; `flutter test test/` green.
- [ ] Verdict recorded on the issue: **adopt / adopt-with-changes / kill**, with 360 dp
      and 1280 dp screenshots side by side.

Production task (filed only if the verdict is adopt):

- [ ] No overlap between queue and any bubble in `rows −1 … rows` for every
      `LevelConfig.all` entry, asserted by a widget/golden test.
- [ ] Each preview draws its silhouette symbol (§6.2) — colour is never the only cue.
- [ ] Top HUD row at 360 dp reports no `RenderFlex` overflow and no reflow when the
      `COMBO` chip appears.
- [ ] Palette comes from the renderer's existing map; no third palette map is added
      (design-system §2 already records two).
- [ ] E2E check QE will run: at phone width, start level 1, fire three shots, and
      confirm the colour that leaves the cannon is the one the queue showed, without
      the player's eye leaving the lower half of the screen.

## Success metrics

| Metric | Baseline | Target | How |
|--------|----------|--------|-----|
| Queue-to-cannon distance (canvas y of queue centre vs. cannon) | ~500 dp | ≤ 1.5 bubble-diameters | Measured in the paint layer |
| 360 dp top-bar overflow | unmeasured | 0 overflow errors, 0 reflow | Widget test at 360 × 640 |
| PX-6 "board reads clearly" (5-player playtest) | none yet | ≥ 4.0 / 5 | Same playtest as vision PX-6, before/after |
| Shots to first committed decision on level 1 | none | −10 % | Playtest stopwatch |

All four are playtest-measurable; none needs telemetry (Anti-pillar 2 holds).

## Scope

- **MVP (now):** the timeboxed spike above. Engine untouched, no new art, no HUD
  removal — both placements coexist behind the flag so the comparison is honest.
- **Later (if adopted):** delete the HUD queue; symbols on previews; retire the arrow
  glyph; design-system delta (§5.1 queue anatomy leaves the stats cluster, §5.3 gains a
  queue column, §5.4 gains a z-order slot); `LevelDisplay` unit test replaced by a
  canvas test.
- **Out of scope:** swapping or skipping the next bubble (needs 44 dp targets and a
  rule change), a second queue column, hold-a-bubble mechanics, any `lib/game/` change,
  and — explicitly — **rotating the playfield so the wall feeds in sideways**, raised in
  the same conversation and declined (Pillar 1 plus an XL engine rewrite; see Risks).

## Risks & dependencies

| Risk / dependency | Assessment | Mitigation |
|-------------------|-----------|------------|
| **Collision with descended bubbles.** At `rows = 9` a 3-item vertical stack (≈ 1.8 bubble-diameters tall) beside the cannon reaches within ~0.1 diameters of the deepest bubble row | Medium — this is the one thing the spike exists to answer | Cap previews at the cannon row, or give the queue a small `surfaceBase` plate; settle it in the demo, not on paper |
| Only **0.2 bubble-diameters** of layout box below the cannon (`boardHeight = rows + 1.2`) | Low if the queue runs beside-and-horizontal; High if it hangs below | Prefer beside-and-horizontal; do not grow `boardHeight` during a spike |
| **Wide-viewport letterboxing.** `offsetX` yields spare pixels beside the board only on wide viewports, so placement behaves differently at 360 dp vs 1280 dp | Medium | Spike screenshots at both widths (acceptance criteria) |
| **UX owns the spec.** §5.1/§5.3/§5.4 currently specify the opposite, and DoR requires a linked UX spec for a player-facing change | Blocking for the production task only | UX-1 is already In review — hand the spike screenshots to UX as the delta input; PM does not design details |
| A third duplicated palette map | Low, but certain if done carelessly | Reuse `bubble_renderer.dart`'s map; delete the HUD entry when the widget dies |
| Disturbing the open release (OPS-13 / v1.1.0, PB-01 #109) | Low — the spike is debug-flagged and ships nothing | Spike ranks below PB-01; the production task is filed after the v1.1.0 QE PASS |
| Scope creep into playfield rotation | Would be Anti-pillar 4 territory: hex-offset parity, `_snapToHex`, `_matchGroupAt`, `_dropDetached`, `descentSlack`, the ±60° aim clamp, every seeded test re-keyed | Recorded out of scope; needs its own ADR if ever revived |

## Competitive reference

Our own matrix ([`competitive-analysis.md`](competitive-analysis.md) §4) tracks queue
*discipline* (the reference draws only from colours still on screen; `_refill` does
not — PB-02) but has **no row for queue placement**, which is how this gap survived
#42. Modern mobile shooters (Bubble Witch, Panda Pop) place the next-bubble preview at
the bottom of the playfield near the launcher, but those rows are marked *inferred* in
§3 and must not be cited as fact. Before the production task is triaged I will add a
**Queue placement** row to the matrix from a citable source with an access date, or
downgrade the "matching the original" claim in #42.

What we do differently: the reference puts the *next* bubble by the launcher and the
*queue* elsewhere; we keep both in one stack at the cannon, and we take chrome out
rather than add it (Pillar 3).

## Open questions

1. **Verdict gate:** does the Product Owner want the spike before UX is engaged, or in
   parallel? *(PM recommendation: spike first — one day, and its screenshots are the
   input UX needs.)*
2. **Which side of the cannon** — left, right, or straddling? UX owns it; the collision
   risk may force the answer.
3. **Does the arrow glyph go**, or stay as the loaded marker? UX decision.
4. **Do previews keep 18 dp on canvas**, where the surrounding context is 40 dp bubbles
   rather than 16 dp text? §5.3 tokens were tuned for the HUD.
5. **Is PB-02 (queue only on-board colours) coupled?** PB-02 is engine-side and already
   ranked. If one developer takes both, PB-02 goes first so the queue is written once.
   *(PM call: yes — PB-02 first.)*
