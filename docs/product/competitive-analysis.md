# Competitive Analysis — Bust-A-Move and Modern Bubble Shooters

| Field | Value |
|-------|-------|
| **Status** | proposed — input to PM-3 / [#66](https://github.com/y0n1/bust_a_move_clone/issues/66) |
| **Owner** | Product Manager |
| **Date** | 2026-10-23 |
| **Task** | PM-1 / [#64](https://github.com/y0n1/bust_a_move_clone/issues/64) |
| **Inputs** | [`bust_a_move_spec.md`](../bust_a_move_spec.md), [`vision.md`](vision.md), `lib/game/engine.dart`, `lib/game/model.dart` |
| **Companions** | [`backlog.md`](backlog.md), [`design-system.md`](../design/design-system.md) |
| **Board state** | Research only. Nothing here is triaged, prioritised for execution, or **Ready**. |

## 1. Scope & method

I compared one reference game and four comparable titles on mechanics, progression,
feedback, accessibility and monetisation, then mapped every mechanic against what the
current build actually does. The build side is **fact** — read directly from
`engine.dart`, `model.dart`, `game_viewmodel.dart` and `bubble_renderer.dart` on
2026-10-23. The competitor side is mixed: three titles have cited sources; one is
described from the genre template and is labelled as an assumption throughout.

**Evidence labels used below:** **Fact** = stated in a cited source or read from the
repo. **Inference** = my analysis of a source or of the code; not directly stated.
**Assumption** = unverified; needs a playtest or a source.

**Honest limits.** I did not play any competitor this session. I did not verify current
store listings, live-ops calendars, or prices. No sales figures, player counts, or
ratings are asserted here; the one review score quoted is cited. Where I could not
verify a mechanic I write `?` rather than guess. Mobile F2P titles change weekly, so
their entries are patterns, not snapshots.

## 2. The reference game — Puzzle Bobble / Bust-A-Move (1994)

| Aspect | Fact |
|--------|------|
| Developer / publisher | Taito (arcade, June 1994) |
| Modes | Single-player **and multiplayer** — the infobox lists both; EGM's reviewer called the two-player mode the highlight |
| Board | A **prearranged pattern** of coloured bubbles at the start of each round |
| Content | 30 levels in the arcade version |
| Aiming | Bubbles travel in straight lines, bouncing off side walls, stopping on contact or at the top |
| Colour queue | The colour fired is random **from the colours still left on the screen** |
| Match rule | 3+ touching same-colour bubbles pop, **along with anything hanging from them** |
| Pressure | After every few shots the ceiling drops, carrying its bubbles down; the cadence is influenced by how many colours remain |
| Anti-stall | Bubbles fire automatically if the player stays idle |
| Feedback | The music speeds up as the bubbles approach the bottom line |

**Why it endured.** Four reasons, in order of importance: (1) one screen, one input,
no hidden state — a newcomer understands it in five seconds; (2) the bounce turns every
shot into a small geometry problem, so mastery is visible and personal; (3) the ceiling
makes every shot cost something, so the player is always spending a budget; (4) the
versus mode converted a solo puzzle into a social one. The cute Bubble Bobble cast and
the short round length did the rest.

**What the mechanic demands of the player.** You do not aim at a bubble; you aim at a
*landing cell* you cannot see directly, often via a wall. You must hold the reflection
in your head, respect that the queue may not give you the colour you want, and accept
that a safe shot is still a shot the ceiling counts. That is the whole skill curve, and
it is why the game is still legible 30 years later.

**Spec discrepancy — flagged, not resolved.** [`bust_a_move_spec.md`](../bust_a_move_spec.md)
says "Single-player experience: No multiplayer modes" and lists a level timer and a
remaining-shot counter. The cited source describes multiplayer and no timer. The spec is
authoritative for this project, so I am **not** overriding it; I am recording that two of
its claims are unsupported by its own citation. See Open Questions.

## 3. Comparable modern bubble shooters

### 3.1 Bubble Witch 3 Saga — King (mobile F2P)

| | |
|---|---|
| **Core loop** | Hand-authored level → clear the goal within a **limited number of moves** → star rating → next level; lives gate retries |
| **Does well** | Board is readable at a glance; generous trajectory preview; goals fit one screen; sessions are 2–5 minutes |
| **Does badly** | Lives/energy gating; booster economy; event pressure; progress can stall behind a paywall rather than a skill wall |
| **Copy** | Level goals beyond "clear the board"; trajectory preview; short authored levels |
| **Do not copy** | Lives/energy, boosters, event FOMO, notifications, streaks |
| **Monetisation** | Boosters, extra lives, immediate level access. King-wide: ads removed in 2013, re-added in 2018. *(Fact for King; **inference** that BW3 follows the same template — I did not verify BW3's current store page.)* |

### 3.2 Panda Pop — Jam City (mobile F2P)

| | |
|---|---|
| **Core loop** | Move-limited levels with a rescue objective layered on the match-3 core; lives, boosters, events |
| **Does well** | A per-level objective gives the board a story beyond "clear it"; strong first-session onboarding |
| **Does badly** | Objective creep obscures the match-3 core; the same gating patterns as every saga title |
| **Copy** | One clear objective per level, stated before the first shot |
| **Do not copy** | Lives, boosters, event calendars, ad interstitials |
| **Monetisation** | Same F2P template. **Assumption** — I did not verify Panda Pop's current live-ops or store listing this session; treat this entry as a genre pattern, not a sourced profile. |

### 3.3 Bubble Shooter — Absolutist (2002), now Ilyon Dynamics

| | |
|---|---|
| **Core loop** | Direct Puzzle Bobble clone: clear the field, lose when the mass reaches the bottom. Modes: **Strategy** (shot limit) and **Arcade** (time limit); scoring modes **Classic** (no limits) and **Sniper** (minimum shots) |
| **Does well** | Zero friction, instant play, no meta between you and the board; mode variety delivered as *modes*, not as an economy |
| **Does badly** | Dated presentation and weak feedback; Pocket Gamer scored it 4/10 in 2013, calling it "a poorly put together, pale imitation of a far more interesting game" |
| **Copy** | Instant play; limits offered as optional modes rather than gates |
| **Do not copy** | Ad-supported interruption; thin feedback; shipping a clone without a reason to prefer it |
| **Monetisation** | Ad-supported and mobile-store distribution; **unverified** for the current build. This is our closest competitor on *distribution* — a web page, not an install. |

### 3.4 Puzzle Bobble Everybubble! — Taito (Switch, 2023)

| | |
|---|---|
| **Core loop** | Premium, hand-authored Puzzle Bobble with story mode plus a 4-player co-op "vs. Space Invaders" mode where players can only aim straight up |
| **Does well** | Pure rules, no monetisation, local co-op, a variant that removes bounce as a deliberate constraint |
| **Does badly** | Console-only reach; full-price gate; content volume we cannot match |
| **Copy** | Premium honesty (no ads, no economy); variants shipped as separate modes |
| **Do not copy** | Content scale as a strategy — five levels with excellent feel beat thirty rushed ones for us |
| **Monetisation** | One-off purchase. **Fact** (release date and mode from the cited source); pricing not verified. |

### 3.5 Monetisation and engagement patterns we name as anti-patterns

| Pattern | Seen in | Why it is an anti-pattern for us | Our rule |
|---------|---------|----------------------------------|----------|
| Lives / energy gating | BW3, Panda Pop | Converts failure into waiting or paying; the loss stops being the player's | Anti-pillar 1 — unlimited retries |
| Booster economy | BW3, Panda Pop | Sells the solution to difficulty the design created; makes levels adversarial | Anti-pillar 1 — no purchases |
| Interstitial / banner ads | Web portals, King post-2018 | Breaks instant play and adds a third-party dependency to a static site | Anti-pillar 1 — none |
| Event FOMO, streaks, notifications | BW3, Panda Pop | Manufactures return instead of earning it; needs a backend we do not have | Anti-pillars 1–2 — none |
| Level-skip purchases | Saga titles | Turns the skill test into a transaction | Anti-pillar 1 — none |
| Difficulty tuned around a purchase | Industry concern, **not** attributed to a specific title here | Any curve that assumes a purchase is out of scope | We tune to the player, not the store |

## 4. Mechanic comparison

`have` = implemented and player-visible. `partial` = present but incomplete, internal, or
not surfaced. `none` = absent. `?` = not verified this session. Ours = v1.0.0 working tree.

| Mechanic | PB94 (ref) | BW3 | Panda Pop | Bubble Shooter | PB Everybubble! | Ours |
|----------|------------|-----|-----------|----------------|-----------------|------|
| **Ceiling attachment** | have — bubbles hang from a moving ceiling | have — inferred | have — inferred | have — clone lineage | have — inferred | **partial** — hex grid; "attached" = connected to the *topmost occupied row*, not a fixed wall (`_dropDetached`) |
| **Bounce aiming** | have — side walls | have — inferred | have — inferred | have — clone lineage | have — inferred | **have** — engine reflects at `x < 0` and `x > cols`; the *guide* shows no bounce |
| **Match-3 pop** | have | have | have | have | have | **have** — `_matchGroupAt`, ≥ 3 same colour |
| **Detached-cluster drop** | have — "bubbles hanging from them" are removed | have — inferred | have — inferred | have — inferred | have — inferred | **have** — `_dropDetached`, 50 pts per fallen bubble |
| **Wall descent** | have — ceiling drops every few shots; cadence depends on colours left | none — move-limited levels (inferred) | none — inferred | none — not in source | have — inferred | **partial** — every `descentInterval` shots; fixed per level; shifts bubbles but never moves the wall |
| **Level timer** | none — source describes no timer | none — move limit instead (inferred) | none — inferred | have — Arcade mode time limit | ? | **none** — descent is the only clock |
| **Shot counter** | none as a limit — descent cadence is shot-based | partial — moves remaining (inferred) | partial — moves (inferred) | have — Strategy mode shot limit | ? | **partial** — `shotsTaken` exists, drives descent, is never shown and never limits |
| **Power-ups** | none in the 1994 original per source; later sequels add specials (unverified) | have — boosters (inferred) | have — boosters (inferred) | ? — varies by version | have — inferred | **none** |
| **Vs-mode** | have — multiplayer; 2P was the review highlight | none | none | none — single-player per source | have — 4-player co-op mode | **none** — anti-pillar 3 |
| **Authored levels** | have — prearranged patterns, 30 levels | have — inferred | have — inferred | have — inferred | have — inferred | **none** — `startLevel` fills the top half randomly |
| **Aim guide** | partial — pointer direction only (inferred) | have — bounce preview (inferred) | have — inferred | partial — straight line (unverified) | ? | **partial** — straight dotted line, 3.5 units, no bounce |
| **Queue drawn from on-board colours** | have — verified | ? | ? | ? | ? | **none** — `_refill` samples the whole level palette uniformly |
| **Queue placement** | **unverified** — the cited gameplay text documents the pointer, colour discipline, descent and idle auto-fire but **no next-bubble display at all** ([Wikipedia, accessed 2026-10-29](https://en.wikipedia.org/wiki/Puzzle_Bobble)); StrategyWiki and Arcade-History returned 403 and no other citable source was found, so "the next bubble sits beside the pointer" is **not established** | ? | ? | ? | ? | **none** — the queue is a widget in the top HUD `Row` (`level_display.dart`), not on the canvas near the cannon. This is the gap PB-13 / #125 addresses. |
| **Idle auto-fire** | have — verified | none | none | ? | none | **none** |
| **Lives / retry** | partial — arcade credits/continues | have — lives (inferred) | have — lives (inferred) | ? | ? | **have** — 3 lives; but a loss re-rolls the board and resets score |
| **Score survives a retry** | have — inferred (arcade convention) | ? | ? | ? | ? | **none** — `startLevel` returns `score: 0` |
| **Local high score** | have — arcade table (inferred; spec claims it) | have — server-side (inferred) | have — inferred | ? | have — inferred | **none** |
| **Audio danger cue** | have — music speeds up as bubbles descend (verified) | ? | ? | ? | ? | **none** |

**What the table says in one line:** we have the *rules* of the reference game but almost
none of its *craft* — the authored boards, the colour discipline, the audio, the retry
fairness — and the two mechanics we do implement (descent, ceiling) differ in ways a
player can feel.

## 5. Where we already differ from the reference

Grounded in `lib/game/engine.dart`, `lib/game/model.dart` and
`lib/gameplay/viewmodel/game_viewmodel.dart` as of 2026-10-23.

1. **Boards are procedural, not authored.** `startLevel` fills `ceil(rows / 2)` rows with
   `rng.nextInt(palette.length)`. Every retry is a different puzzle. The reference's
   prearranged patterns are the reason its levels are memorable.
2. **The wall never moves; only the bubbles do.** `_applyDescent` shifts every bubble down
   one row and leaves row 0 empty. In the reference the ceiling moves *with* the cluster.
   Consequence: after a descent a shot can attach **above** the cluster, in empty row 0.
3. **The colour queue ignores the board.** `_refill` draws uniformly from the level palette.
   The reference draws only from colours still on the screen. We can hand the player a
   colour that has no legal target.
4. **Descent cadence is fixed per level.** `descentInterval` is a constant in
   `LevelConfig`; the reference derives cadence from how many colours remain.
5. **No timer, no idle auto-fire.** Descent is the only pressure, and it only advances
   when the player shoots — so a passive player cannot lose.
6. **A life loss erases the score and re-rolls the board.** `_settleShotAt` calls
   `startLevel(initialLives: lives, level: s.level)`, which resets `score` to 0 and
   generates a new random board. Only lives and the level number survive.
7. **Combo is a cross-shot streak, not chain depth.** `combo + 1` when a shot pops ≥ 3,
   reset to 0 otherwise. Only one match group is evaluated per shot; the "chain" is the
   detached drop, scored separately at 50 per fallen bubble.
8. **The palette is the first N enum values.** `_activePalette` is
   `BubbleColor.values.sublist(0, activeColorCount)`, so 4-colour levels never show purple
   or orange, and 5-colour levels never show orange. Six colours only appear on levels 4+.
9. **Aim clamping lives in the ViewModel, not the engine.** `updateAim` clamps to ±60°.
   The rule that decides which shots are legal is therefore in the UI layer.
10. **Collision is deliberately forgiving.** `_hitsBubbleOrWall` uses squared distance
    `<= 0.9`, not `<= 1.0`, so a shot settles slightly before it visually touches.

### 5.1 Correctness risks found while reading (read-only, not reproduced)

| # | Risk | Evidence | Status |
|---|------|----------|--------|
| R1 | **Empty-top-row orphan.** After descent, row 0 is empty. A shot can stop at the top wall without touching the cluster and attach at row 0. If a *different-coloured* bubble then remains in row 0 after a match pops beside it, `_dropDetached` starts its flood fill from row 0, finds no path down to the cluster, and drops the entire board. | `_hitsBubbleOrWall` returns true at `p.y <= 0.5`; `_dropDetached` flood-fills from the topmost occupied row | **Inference from code.** Needs a failing test before any level tuning. |
| R2 | **Score popup reports the running total.** `'+${_state.score}'` prints cumulative score, not points gained. | `game_viewmodel.dart` L103 | **Fact.** A 300-point pop after 1 200 reads `+1500`. |
| R3 | **`_nearestFreeCell` rejects row `rows`.** Descent can place bubbles there. | `_nearestFreeCell` guards `r > rows` | Recorded in [`memories/repo/facts.md`](../../memories/repo/facts.md); still open. |
| R4 | **Death-line mismatch.** Memory says the renderer draws at `rows - 1`; the vision says both use `rows`. | `memories/repo/facts.md` vs `bubble_renderer.dart` | **Unresolved.** Verify before "fixing". |

## 6. Opportunities

Each is tied to a gap in §4 and a pillar in [`vision.md`](vision.md) §3.

1. **Bounce-preview aim guide** — extend the straight guide to the first wall bounce. *(Aim guide: partial. Pillar 2.)*
2. **Authored levels 1–5** — replace random fill with five fixed, tested patterns. *(Authored levels: none. Pillars 1, 5.)*
3. **Queue only on-board colours** — sample `_refill` from colours still present. *(Queue discipline: none. Pillar 1.)*
4. **Score survives a life loss** — carry `score` through the reset. *(Score persistence: none. Pillar 3.)*
5. **Seal the ceiling** — move the attach boundary with the cluster so shots cannot land above it. *(Ceiling: partial. Pillars 1, 4; fixes R1.)*
6. **Shot budget as an optional mode** — a visible counter and a limit, offered as a mode, not a gate. *(Shot counter: partial. Pillar 5.)*
7. **Local high score** — one persisted best, no backend. *(High score: none. Pillar 5.)*
8. **Sound pass with a danger cue** — shot, pop, descent, and a tension layer near the line. *(Audio: none. Pillar 3.)*

Deliberately **not** in this list: power-ups and an endless endgame. Both are real gaps,
but they are Wave 3 in [`backlog.md`](backlog.md) — they add rules before the existing
rules are honest.

## 7. Threats — reasons this could fail

1. **The game is already good enough to stop.** It is deployed, playable, and green. Every
   item above improves a working game; without a playtest we are guessing which one a
   player would notice. The cheapest way to lose is to polish the wrong thing.
2. **We cannot measure anything.** No telemetry, no event log. Every success metric in the
   vision is a moderated-playtest estimate. "It worked" will be an opinion.
3. **Content thinness.** Five configs, then level 5 forever. Authored levels fix the feel
   but cost the most design time per level, and five is still five.
4. **Fidelity drift.** We already differ on ten behaviours (§5). Each is defensible; ten
   undocumented ones turn "faithful clone" into "vaguely similar game".
5. **Mobile is unproven.** The charter's 60 fps and <100 ms gates have never been measured
   on a mid-range phone. A Canvas game in a mobile browser is exactly where that fails.
6. **Scope creep toward F2P.** The genre's economics push toward lives, boosters and
   events. It will arrive disguised as "just one daily challenge".
7. **Accessibility debt.** Colour is the only game channel, six colours are in play, and
   there is no keyboard path. That is a release gate we currently fail, not a nice-to-have.
8. **Single-maintainer risk.** Feel parameters live as literals in the engine and the
   painter. Without ADRs they will be "tuned" by accident.

## 8. Sources

All accessed 2026-10-23.

| Claim | Source |
|-------|--------|
| Puzzle Bobble: Taito, June 1994, modes single + multiplayer, prearranged patterns, 30 levels, bounce, colour queue from on-screen colours, ceiling descent, idle auto-fire, music tempo | [Wikipedia — Puzzle Bobble](https://en.wikipedia.org/wiki/Puzzle_Bobble) |
| EGM called the two-player mode the highlight | Wikipedia — Puzzle Bobble, Reception (citing EGM #68, March 1995) |
| Everybubble!: Switch, 23 May 2023; 4-player "vs. Space Invaders" co-op with straight-up aiming | Wikipedia — Puzzle Bobble §Legacy (citing [Gematsu, 2023-02-02](https://www.gematsu.com/2023/02/puzzle-bobble-everybubble-launches-may-23) and [Gematsu, 2023-01-13](https://www.gematsu.com/2023/01/puzzle-bobble-everybubble-includes-puzzle-bobble-vs-space-invaders-mode)) |
| Bubble Shooter: Absolutist 2002, clone of Puzzle Bobble, Strategy/Arcade modes, Classic/Sniper scoring, Pocket Gamer 4/10 (2013) | [Wikipedia — Bubble Shooter](https://en.wikipedia.org/wiki/Bubble_Shooter) |
| Bubble Witch Saga: King's first "saga" title (Oct 2011), limited-turn levels; King monetisation (boosters, lives, level access), ads removed 2013, re-added 2018 | [Wikipedia — King (company)](https://en.wikipedia.org/wiki/King_(company)) |
| Panda Pop mechanics and monetisation | **No source verified.** Treated as a genre assumption throughout §3.2. |
| Our current behaviour | `lib/game/engine.dart`, `lib/game/model.dart`, `lib/gameplay/viewmodel/game_viewmodel.dart`, `lib/gameplay/ui/renderer/bubble_renderer.dart` |

## 9. Open questions

| # | Question | Owner |
|---|----------|-------|
| C1 | The spec says "no multiplayer" but the cited source documents a 2P mode. Which is authoritative for our fidelity claim? | Product Owner |
| C2 | The spec lists a level timer and a shot counter; the source supports neither. Do we implement them as spec compliance or drop them as unsupported? | Product Owner |
| C3 | Should the ceiling model match the reference (attach boundary moves with the cluster), accepting an engine change and a new test class? | Product Owner + Engine Dev |
| C4 | Is a local high score acceptable in v1.x, given it writes to browser storage? | Product Owner |
| C5 | Are we allowed to source audio assets, and under what licence? | Product Owner + UX |
| C6 | Where does the reference actually show the upcoming bubble — beside the pointer, in a side panel, or nowhere on the playfield? [#42](https://github.com/y0n1/bust_a_move_clone/issues/42) asserts "next to the cannon on the canvas (matching the original Bust-A-Move)"; **no citable source was found on 2026-10-29** (§4 "Queue placement"), so the fidelity claim in that issue is downgraded to unverified. Blocks the PB-13 production task, not its spike. | PM + UX |
