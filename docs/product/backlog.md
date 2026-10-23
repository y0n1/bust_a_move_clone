# Prioritized Feature Backlog

| Field | Value |
|-------|-------|
| **Status** | proposed — awaiting Product Owner review |
| **Owner** | Product Manager |
| **Date** | 2026-10-23 |
| **Task** | PM-3 / [#66](https://github.com/y0n1/bust_a_move_clone/issues/66) |
| **Inputs** | [`competitive-analysis.md`](competitive-analysis.md), [`vision.md`](vision.md), [`bust_a_move_spec.md`](../bust_a_move_spec.md), `lib/game/engine.dart` |
| **Companions** | [`design-system.md`](../design/design-system.md), [`2026-10-23-kickoff.md`](../status/2026-10-23-kickoff.md) |

## 1. How to read this

This file ranks product opportunities by expected player value per unit of effort, and
gives each one the thinnest end-to-end increment that would prove or disprove it. It is
a **proposal**, not a plan.

> **This file PROPOSES. The Product Owner DISPOSES.**
> No item here is triaged, prioritised for execution, assigned, or **Ready**. Nothing
> here has been filed as a GitHub issue. Priority, branch and assignee are set only by
> the Product Owner. The GitHub board (Project #3) remains the single source of truth
> for status; if this file and the board disagree, the board wins.

Research and design may happen before triage ([charter §14](../agent-team.md)); writing
this file is not implementation and authorises none.

## 2. Scoring method

**RICE** = `(Reach × Impact × Confidence) / Effort`. Every score below shows its inputs
so it can be recomputed.

| Input | Scale | Meaning |
|-------|-------|---------|
| **Reach** | 1–5 | 5 = every session; 4 = most sessions; 3 = some players; 2 = niche; 1 = negligible |
| **Impact** | 1–5 | 5 = changes whether the core promise lands; 3 = noticeable; 1 = cosmetic |
| **Confidence** | 0.5–1.0 | 1.0 = verified source or reproduced behaviour; 0.8 = strong inference; 0.5 = plausible, untested |
| **Effort** | dev-weeks | Includes tests and the QE handoff. **XS** ≤ 0.5, **S** 0.75–1.0, **M** 1.5–2.5, **L** 3.0–4.0, **XL** > 4.0 |

**Caveat:** Reach and Impact are judgement calls, not measurements — there is no
telemetry (vision §5). The score orders a conversation; it does not prove anything.

## 3. Prioritised opportunities

| ID | Opportunity | Source | Player value | Effort | RICE | Smallest testable slice (demoable) |
|----|-------------|--------|--------------|--------|------|-----------------------------------|
| **PB-01** | **Honest shot score** — popup shows points gained, not running total (P3) | Vision P3; `game_viewmodel.dart` L103 | Trust: the number on screen is the number you earned | XS · 0.5 wk | **30.0** = (5×3×1.0)/0.5 | Score 1 200, then pop 3 (300 pts). Popup reads `+300`. Widget test asserts the string; one-shot demo. |
| **PB-02** | **Queue only on-board colours** (P1) | CA §4 row 12; `engine.dart` `_refill` | Fairness: no dead shots from a colour that is not on the board | XS · 0.5 wk | **27.0** = (5×3×0.9)/0.5 | Board with red/green/blue only; fire 20 shots; queue never yields yellow, purple or orange. Seeded headless test. |
| **PB-05** | **Score survives a life loss** (P3) | CA §5.6; `_settleShotAt` → `startLevel` | Fairness: losing a life should not erase the run's points | S · 0.75 wk | **19.2** = (4×4×0.9)/0.75 | Lose a life at 1 200; next board starts at 1 200, same level, lives −1. Engine test. |
| **PB-03** | **Bounce-preview aim guide** (P2) | CA §4 row 11; Vision P2 | Readability: bank shots become intentional instead of lucky | S · 1.0 wk | **18.0** = (5×4×0.9)/1.0 | Aim 45° at a wall; guide shows one bounce segment ending at the impact cell. Debug overlay: predicted cell == settled cell for ≥ 9 of 10 sampled angles. |
| **PB-07** | **Pause / resume** (P3) | CA §4 row 6; design-system §5.5 (no paused state) | Interruption tolerance in a browser tab | XS · 0.5 wk | **12.8** = (4×2×0.8)/0.5 | Esc freezes the ticker; resume returns the identical `GameState`. Test asserts zero ticks while paused. |
| **PB-04** | **Authored levels 1–5** (P1, P5) | CA §4 row 10; Vision P5 | Levels feel designed, replayable and fair; makes retries identical | M · 2.0 wk | **10.0** = (5×5×0.8)/2.0 | Level 1 loads the same fixture every run. Golden test on the bubble map; a recorded input script clears it in ≤ 12 shots. |
| **PB-09** | **Local high score** (P5) | Spec §Core; Vision Q4 | A reason to replay the same five levels | S · 1.0 wk | **8.4** = (4×3×0.7)/1.0 | Clear level 1 at 3 400; reload; start screen shows `BEST 3 400`. Storage test with a fake store. |
| **PB-08** | **Shot budget + HUD counter, as a mode** (P5) | Spec §Core; Vision Q2 | A legible second pressure; enables score-attack | S · 1.0 wk | **7.2** = (4×3×0.6)/1.0 | HUD shows `SHOTS 7/20`; at 20 without a clear the level ends with a distinct status. Engine + widget test. |
| **PB-06** | **Seal the ceiling** — attach boundary moves with the cluster (P1, P4) | CA §5.1 R1 | Removes an unintended board-clear exploit; matches the reference | M · 2.0 wk | **7.0** = (5×4×0.7)/2.0 | Construct the post-descent gap state, fire into it, assert no mass drop. **Failing test written first.** |
| **PB-10** | **Sound pass** — shot, pop, descent, danger cue, mute (P3) | CA §4 row 17; Spec | Feel; tension that rises as the wall nears the line | M · 2.5 wk | **6.4** = (5×4×0.8)/2.5 | Four SFX plus a mute toggle that persists; no audio before the first interaction (browser autoplay policy). |
| **PB-12** | **Defined endgame / endless ramp** (P5) | Vision Q3; `LevelConfig.forLevel` | The run has an ending or an honest endless mode | M · 1.5 wk | **3.0** = (3×3×0.5)/1.5 | After level 5, level 6 shows a new layout and a documented ramp; a 20-shot scripted run reaches level 7. |
| **PB-11** | **Special bubbles: bomb + colour-change** (P1) | Spec §Core; Vision Q8 | Relief valve for bad boards; expressive play | L · 3.0 wk | **2.4** = (3×4×0.6)/3.0 | One bomb per level; popping it clears radius 1 and reports the count. Headless test. |

**Do nothing** is a real option and currently scores well: the game is deployed, green,
and playable. PB-01…PB-05 exist because they fix things a player can feel today, not
because the feature list looks short.

### 3.1 Assumptions behind the scores

| Item | Assumption |
|------|------------|
| PB-02 | The reference's on-board-colour rule is worth copying (verified for PB94, applied to us by inference). |
| PB-03 | A one-bounce preview does not trivialise the game. If it does, cap it to 0.75 of the board. |
| PB-04 | Authored boards beat procedural ones for a five-level game. **Untested** — no playtest yet. |
| PB-06 | The orphan exploit (CA §5.1 R1) is reachable. Inferred from code reading, not reproduced. |
| PB-08 | A shot budget adds tension rather than confusion. The spec lists it; the cited source does not. |
| PB-09 | A local best score motivates replay. No telemetry; this is a genre assumption. |
| PB-10 | Audio materially improves feel. Unmeasured; asset licensing unresolved (CA §9 C5). |
| PB-11 | Power-ups add expression without diluting the skill test. Highest uncertainty in the list. |
| PB-12 | The endgame shape is undecided (Vision Q3), so any ramp is provisional. |

## 4. Sequencing recommendation

Three waves. Each wave is demoable on its own; nothing in a later wave is required for an
earlier one to be worth shipping.

### Wave 1 — Prove the core (no new rules, no new assets)

**PB-01 → PB-02 → PB-05 → PB-03 → PB-07.** All ≤ 1 dev-week, all touch existing
behaviour, none needs a UX spec beyond the design system.

*Exit criterion:* a first-time player can explain every number on screen and every loss,
and a bank shot is aimable rather than lucky. This is the smallest set that makes the
existing five levels feel intentional.

### Wave 2 — Add depth

**PB-04 → PB-06 → PB-08 → PB-09 → PB-10.**

| Item | Depends on | Why |
|------|------------|-----|
| PB-06 | PB-04 | Authored layouts must be verified against the sealed ceiling, or the fixtures encode the exploit. |
| PB-09 | PB-05 | Persist a score only after it is honest and survives a retry. |
| PB-08 | UX spec | A new HUD element and a new end-of-level state need a design spec. |
| PB-10 | Asset approval | Licence and sourcing must be settled before implementation (CA §9 C5). |
| PB-04 | — | Independent, but the largest content cost in the list. |

*Exit criterion:* the five levels are authored, the retry loop is fair, and the run has a
score worth chasing.

### Wave 3 — Optional

**PB-12** (after PB-04 and PB-06) and **PB-11** (after PB-06 plus an engine ADR for the
special-bubble rule). Both add rules; both should wait until the base rules are honest.
If Wave 1 and 2 slip, this wave is what gets cut.

## 5. Explicitly deferred

| Deferred | Reason | Revisit trigger |
|----------|--------|-----------------|
| Level select | Five levels; there is nothing to select. | ≥ 15 levels exist. |
| Level timer | A second clock makes a loss unattributable; the cited source describes no timer (CA §9 C2). | Playtest shows descent alone is too slow. |
| Idle auto-fire | Arcade coin-drop artefact; hostile in a browser tab the player alt-tabs away from. | Only if a "classic arcade" mode is scoped. |
| Vs / multiplayer | Anti-pillar 3; `lib/net/` and `server/` do not exist. | Separately scoped by the Multiplayer Developer. |
| Daily challenge, streaks, energy, ads, IAP | Anti-pillars 1–2. | Product Owner reverses anti-pillar 1 in writing. |
| Accounts, cloud leaderboard, telemetry backend | Anti-pillar 2; static GitHub Pages, no server. | Product Owner approves a backend. |
| Colour-blind shape cues | Not a PM item — UX owns it ([`design-system.md`](../design/design-system.md) §6.2) and QE gates it. | Already specified; track as a release dependency, not a backlog item. |
| Engine or architecture rewrite | Anti-pillar 4; the deterministic pure-Dart engine is the asset. | Never without an ADR. |
| Level configs 6–10 | Content cost; PB-04 must prove the layout format first. | After PB-04 ships. |
| In-game tutorial / onboarding overlay | Level 1 plus the aim line is the tutorial; adding a modal delays first pop (PX-1). | Playtest shows first-session confusion. |

## 6. Mapping to the board

- These opportunities are **not filed as issues**. #64 (competitive analysis) and #66
  (this backlog) are research tasks; the PB IDs are internal to this document.
- Filing requires the Product Owner's approval. When approved, each PB becomes an issue
  using the charter's task shape (goal, context, acceptance criteria, test plan, out of
  scope) and links back to this file and the matching `competitive-analysis.md` anchor.
- Until then, the board stays at 27 Backlog items (#64–#90) and zero Ready. Nothing here
  changes that.
- If a PB item is later rejected, record the reason here rather than deleting the row —
  the rejection is evidence.

## 7. Traceability to the vision

| Pillar | Backlog items |
|--------|---------------|
| **P1 — Faithful core, better feel** | PB-02, PB-04, PB-06, PB-11 |
| **P2 — Readable at a glance** | PB-03, PB-08 |
| **P3 — Immediate, honest feedback** | PB-01, PB-05, PB-07, PB-10 |
| **P4 — Deterministic, testable rules** | PB-04, PB-06 (both test-first) |
| **P5 — Bite-sized mastery** | PB-04, PB-08, PB-09, PB-12 |

| Anti-pillar | What it rules out here |
|-------------|------------------------|
| **1 — No monetisation/engagement** | No lives gate, boosters, ads, events, or streaks in any wave. PB-08 is a *mode*, not a paywall. |
| **2 — No live-service scope** | PB-09 is local storage only; no accounts, no telemetry, no server. |
| **3 — No multiplayer** | Vs-mode stays out of the backlog despite being a reference-game strength. |
| **4 — No engine/architecture rewrite** | PB-06 is a rule change with tests, not a new physics or grid model. |
| **5 — No spec-checklist cargo cult** | The timer is deferred, the shot counter is a mode, and power-ups sit in Wave 3. |

## 8. Open questions for the Product Owner

| # | Question | Blocks |
|---|----------|--------|
| B1 | Approve or reject the eight Wave-1 candidates, and confirm the "no new rules first" sequencing. | Any filing |
| B2 | Does the ceiling model change (PB-06) require an ADR before triage? | PB-06 |
| B3 | Is browser-storage persistence (PB-09) acceptable, or does it need a privacy note? | PB-09 |
| B4 | Is the spec's timer/shot-counter claim binding, or advisory? (CA §9 C2) | PB-08, deferred timer |
| B5 | Should Wave 1 be filed as one issue or five? | Filing shape |
