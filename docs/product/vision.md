# Product Vision — Bust-A-Move Clone

- **Status:** proposed (awaiting Product Owner review)
- **Owner:** Product Manager
- **Date:** 2026-10-23
- **Task:** PM-2 / [#65](https://github.com/y0n1/bust_a_move_clone/issues/65)
- **Inputs:** [`bust_a_move_spec.md`](../bust_a_move_spec.md),
  [`agent-team.md`](../agent-team.md),
  [`2026-10-23-kickoff.md`](../status/2026-10-23-kickoff.md),
  `lib/game/engine.dart`, `lib/game/model.dart`
- **Companions:** PM-1 / #64 (competitive analysis), PM-3 / #66 (backlog),
  UX-1 / #67 (design system). This document does not duplicate them.

## 1. Vision statement

> **A faithful, polished Bust-A-Move you can open in a browser tab and be
> aiming within seconds — where every shot is readable, every pop is
> satisfying, and every loss is clearly your own.**

This is a clone of the 1994 arcade bubble-shooter, not a re-skin of a modern
mobile puzzler. The rules stay recognisable: aim, bounce off walls, match three
or more, chain the pop, drop what is no longer attached, and clear the board
before the descending wall reaches the cannon. What differentiates us is not
content volume or monetisation — it is **feel, clarity, and fairness** in a
zero-install web build. The engine is deterministic, so skill is rewarded and
defects are reproducible. The scope is deliberately small: one player, no
backend, no accounts.

**Positioning (inference, to be validated by PM-1 / #64):** the original arcade
game, modern free-to-play mobile bubble shooters, and web-portal clones all
compete here. We compete on instant play, tight game feel, and honest rules —
not on live-ops, meta-progression, or monetisation.

---

## 2. Target player

| Segment | Who | Situation | What they want |
|---------|-----|-----------|----------------|
| **Primary** | Lapsed arcade/puzzle players (~25–45) who played *Puzzle Bobble* / *Bust-A-Move* or a browser bubble shooter | A 3–8 minute break on desktop Chrome or a mobile browser; no install, no account | The game they remember, but smoother and fairer |
| **Secondary** | Score chasers and optimisation-minded players | Repeat sessions on the same levels | A scoring system where precision and combos visibly pay off |
| **Not for (v1.x)** | Players seeking story, collection/meta-progression, or live social competition | — | Out of scope: no narrative, no economy, no backend |

**Core fantasy:** *“I can see the shot, I take it, and the whole board answers.”*
The feeling we optimise for is **precision** — a shot that lands where the
player intended, a pop that reads instantly, and a loss the player can explain.

## 3. Design pillars

Five pillars. Each is a constraint on decisions, not a slogan. A feature that
weakens one needs an explicit trade-off recorded in an ADR.

### Pillar 1 — Faithful core, better feel

**Definition:** The 1994 rules are the contract; polish is how we beat the
original, not new rules that replace it.

**Implementation means:**
- Keep the existing loop as the source of truth: match ≥3, chain pops, drop
  detached clusters, descend the wall. Do not replace it with physics or a
  different match rule.
- Any new mechanic is **additive** and must not invalidate existing seeded
  tests; record deviations in `docs/decisions/`.
- Feel parameters (collision tolerance, aim clamp, projectile speed) are
  tunable but live in the engine as explicit values, not hidden magic.

**Grounded in:** `lib/game/engine.dart` — `_settleShotAt` (match, combo,
detached drop, descent, life loss), `_dropDetached`, `_applyDescent`;
`_hitsBubbleOrWall` uses a deliberately forgiving squared-distance threshold
(`<= 0.9`); `GameViewModel.updateAim` clamps aim to ±60°.

### Pillar 2 — Readable at a glance

**Definition:** A first-time player can tell what is on the board, where the
shot will go, and how close they are to losing, in one look.

**Implementation means:**
- Preserve the three danger/state cues that already exist: the death line,
  the level-clear progress bar, and the next-colour queue.
- Extend the existing dotted aim line (currently straight, 3.5 bubble-lengths)
  to show the first wall bounce. The engine bounces projectiles off the side
  walls, so a straight-only guide under-informs bank shots.
- Colour must never be the only cue (charter accessibility gate). Six colours
  are in play; colour-blind distinguishability and/or shape cues are required.
- Keep the death line and the loss rule in sync: both currently use
  `engine.rows` (`bubble_renderer.dart` and `_computeStatus`), but
  `memories/repo/facts.md` still records a mismatch. Correct that memory so it
  does not drive a false fix.

**Grounded in:** `lib/gameplay/ui/renderer/bubble_renderer.dart` (death line,
progress bar at the level-progress block); `lib/gameplay/ui/hud/level_display.dart`
(lives, level, next queue); `lib/game/model.dart` (`initialBubbleCount` exists
specifically to drive the progress bar).

### Pillar 3 — Immediate, honest feedback

**Definition:** Every input answers within the same frame, and every number the
game shows is the number the player earned.

**Implementation means:**
- Keep the 60 Hz ticker and the ViewModel-owned juice layer (popups, particles,
  shake, recoil, trail). FX must never delay the next shot or change engine
  state.
- Fix feedback that currently misreports: the score popup shows the **total**
  score (`_state.score`) rather than the points gained on that shot. A popup
  that says “+1200” after a 300-point pop is dishonest feedback.
- Hold the charter budget: pointer-to-aim feedback under 100 ms; animation must
  not gate input.
- Prefer fewer, clearer effects over more, noisier ones. Juice that obscures
  the board violates Pillar 2.

**Grounded in:** `lib/gameplay/viewmodel/game_viewmodel.dart` (`Ticker`,
`ScorePopup`, `ParticleBurst`, `_shakeElapsedMs`, `_recoilElapsedMs`, `_trail`);
`lib/gameplay/ui/renderer/bubble_renderer.dart`; charter performance and
accessibility gates in `docs/agent-team.md` §10.

### Pillar 4 — Deterministic, testable rules

**Definition:** The same seed and the same inputs produce the same game, so
skill is meaningful and every bug is reproducible.

**Implementation means:**
- No ambient randomness or wall-clock time in `lib/game/`. All randomness comes
  from the injected `math.Random`.
- Keep `GameState` immutable: the engine returns a new snapshot per mutation.
- Every new rule ships with headless tests using a fixed seed. No Flutter
  imports in the domain layer.
- Extend this to replay: a recorded seed + input sequence should reproduce a
  final state (QE-9 / #77).

**Grounded in:** `lib/game/model.dart` (`GameState` value object, `copyWith`);
`lib/game/engine.dart` (constructor takes `rng`; `Engine.forLevel`); seeded
tests in `test/engine_test.dart` and `test/descent_test.dart`; guardrails in
`AGENTS.md` §4.

### Pillar 5 — Bite-sized mastery

**Definition:** One level is a 1–3 minute skill test worth replaying for a
better score, not a grind.

**Implementation means:**
- Keep level pressure short and legible: wall descent is the clock, measured in
  shots (`descentInterval`), not real time.
- Make score expressive: combos and large pops must visibly beat safe, slow
  play. The existing multiplier and drop bonus are the lever — tune them, do
  not add a second scoring currency.
- Restart must stay ≤ 1 tap and must preserve the player's understanding of why
  they lost.
- Levels 6+ currently reuse the level-5 config. Decide whether that is the
  intended endless endgame or a gap (see Open Questions).

**Grounded in:** `lib/game/engine.dart` — `LevelConfig.all` (five configs;
`forLevel` falls back to level 5), `_popScore` (100/bubble, 4+ bonus),
`_dropScore` (50/fallen bubble), `combo` multiplier in `_settleShotAt`;
`lib/gameplay/viewmodel/game_viewmodel.dart` — `restart()` advances the level
on win and replays the current level on life loss.

## 4. Anti-pillars — what we will not do

1. **No monetisation or engagement mechanics.** No ads, in-app purchases,
   energy timers, loot boxes, streaks, notifications, or artificial scarcity.
   This is a free browser game; retention comes from the loop being fun.
2. **No live-service scope.** No accounts, cloud saves, server-side
   leaderboards, daily challenges, or telemetry backend in v1.x. If a high-score
   table ships, it is local-only and explicitly approved (see Open Questions).
3. **No multiplayer until it is separately scoped.** The spec is single-player.
   `lib/net/` and `server/` do not exist; the Multiplayer Developer role owns
   future work, not this vision.
4. **No engine or architecture rewrite.** No rigid-body physics, no replacing
   the hex grid, no Flutter imports in `lib/game/`, no migration to
   Riverpod/Provider. The deterministic pure-Dart engine is the asset.
5. **No spec-checklist cargo cult, and no heavy assets.** The spec lists a
   timer, shot counter, pause, level select, and power-ups; each is a
   **candidate**, not an obligation, and needs evidence of player value. No 3D,
   video, or large sprite atlases that break instant web play.

## 5. Success metrics

**Measurement reality:** there is no analytics backend today (static GitHub
Pages, see `docs/ops/deployment.md`). Only moderated playtests and values
already in `GameState` are available. Targets are **proposals** for the Product
Owner to confirm, not commitments.

### 5.1 Player-experience metrics

| ID | Metric | Proposed target | How measured | Instrumentation gap |
|----|--------|-----------------|--------------|---------------------|
| PX-1 | Time to first pop | Median ≤ 15 s from PLAY to first 3+ pop | Stopwatch in moderated playtest; or timestamps around `GameViewModel.fire()` and shot settle | No event log |
| PX-2 | Level 1 clear rate | ≥ 60% of first-time players clear level 1 within 3 lives | Playtest observation; log `GameStatus` + `lives` at level end | No event log |
| PX-3 | Shots per cleared level | Median ≤ 12 on level 1; no level median > 25 | `GameState.shotsTaken` at `GameStatus.won` — the field already exists | Field exists, nothing records it |
| PX-4 | Continue after loss | ≥ 70% of losses followed by CONTINUE within 10 s | `GameViewModel.restart()` path | No event log |
| PX-5 | Session length | Median 3–8 minutes; < 10% of sessions over 20 minutes | Session start/end events | No event log |
| PX-6 | Perceived feel | ≥ 4.0 / 5 on “aim feels responsive” and “pops feel satisfying” | 5-player moderated playtest survey | None — manual only |

### 5.2 Engineering-quality metrics

| ID | Metric | Proposed target | How measured | Instrumentation gap |
|----|--------|-----------------|--------------|---------------------|
| EQ-1 | Static analysis | 0 issues | `flutter analyze --fatal-infos` in CI | Enforced today |
| EQ-2 | Test suite | 100% pass; ≥ 70% line coverage of `lib/game/` | `flutter test --coverage` (lcov) | Coverage not collected (QE-2 / #70); baseline unknown |
| EQ-3 | Frame rate | p95 ≥ 55 fps during a full level | Flutter DevTools / Chrome tracing on reference hardware | No trace yet (QE-4 / #72); reference hardware undefined |
| EQ-4 | Input latency | Pointer-to-aim < 100 ms | DevTools frame timeline; charter gate | Manual only |
| EQ-5 | Web payload | `main.dart.js` gzip ≤ 0.60 MB (current 0.54 MB, +10% cap) | Build artifact size in CI | Gzipped size reported by the `build-web` job (OPS-3 / #81) |
| EQ-6 | Determinism | Same seed + inputs ⇒ identical final `GameState`; 100% of engine tests seeded | Seeded tests + replay test | Replay test not written (QE-9 / #77) |
| EQ-7 | Release defects | 0 open P0/P1 at release | Board labels + QE verification report | Process exists; no defect taxonomy yet |

> **Not measurable today:** crash-free sessions, drop-off by level, and
> returning-player rate. All require a backend or client telemetry, which is
> currently a non-goal (see Anti-pillar 2). Do not cite these numbers until the
> Product Owner approves an instrumentation approach.

### 5.3 Minimum instrumentation

In-memory event counters (level start/end, shots, lives lost, restart, session)
behind a debug flag and exportable as JSON; a seeded replay harness; and a named
reference device/browser for fps and latency. None are Ready tasks — inputs to
PM-3 / #66.

## 6. Open questions for the Product Owner

| # | Question | Why it matters |
|---|----------|----------------|
| Q1 | Is desktop Chrome the only first-class target, or must mobile browsers be equally supported? | Drives layout, touch input, fps budgets, and the reference device for EQ-3/EQ-4 |
| Q2 | The spec mentions a level timer and a remaining-shot counter; the engine implements neither (`lib/game/engine.dart` has no timer or shot limit). Do we add them? | Changes the difficulty model and the claim of fidelity; wall descent is currently the only clock |
| Q3 | Levels 6+ reuse the level-5 config. Is “endless at max difficulty” the intended endgame, or do we need a defined final level? | Determines whether the game needs an ending, credits, or a score-attack mode |
| Q4 | The spec mentions a high-score table. With no backend, is a local-only (browser storage) high score in v1.x scope? | Adds persistence, a new UI surface, and privacy considerations |
| Q5 | On life loss the engine resets the board to a fresh layout (`startLevel`). Should a life loss preserve board progress instead? | Fairness and difficulty contract; current behaviour discards the player's work |
| Q6 | Is any client telemetry permitted on GitHub Pages, or must all metrics stay playtest-only? | Without telemetry, PX-1…PX-5 are directional playtest data, not production metrics |
| Q7 | Does WCAG 2.1 AA apply to the canvas game itself (shape/pattern cues, reduced motion, keyboard aiming)? | The charter's “colour is never the only cue” gate affects the six-colour palette and HUD design |
| Q8 | Are power-ups (colour-change, bomb) and pause/level select candidates for v1.x, or deferred? | Prevents the backlog from implying commitments the vision does not make |
| Q9 | Confirm the monetisation stance: “never” or “not now”? | Anti-pillar 1 is only credible if the Product Owner agrees it is durable |

## 7. Evidence base

- **Rules and scope:** [`docs/bust_a_move_spec.md`](../bust_a_move_spec.md) —
  match-3, chain reactions, wall descent, lives/continues, high-score table,
  power-ups, single-player, retro aesthetic, replay value. The spec cites
  [Wikipedia – Bust A Move](https://en.wikipedia.org/wiki/Bust_a_Move) for
  release and design facts; no new external claims are made here.
- **Current behaviour:** `lib/game/engine.dart`, `lib/game/model.dart`,
  `lib/gameplay/viewmodel/game_viewmodel.dart`,
  `lib/gameplay/ui/renderer/bubble_renderer.dart`, `lib/gameplay/ui/hud/`,
  `lib/gameplay/ui/game_screen.dart`, `lib/start_screen/start_screen.dart`.
- **Delivery baseline:** [`2026-10-23-kickoff.md`](../status/2026-10-23-kickoff.md)
  — 45 tests, analyze clean, v1.0.0 deployed; no tag, smoke/E2E, a11y or perf evidence.
- **Quality gates:** [`agent-team.md`](../agent-team.md) §10 — 60 fps, input
  feedback < 100 ms, WCAG 2.1 AA, colour never the only cue.
- **Size baseline:** `memories/repo/facts.md` — `main.dart.js` 0.54 MB gzip,
  `canvaskit.wasm` 2.79 MB gzip. No load-time budget yet (see Q1/EQ-5).

*This vision is a proposal. It becomes authoritative when the Product Owner
accepts it; until then, the spec and the charter govern.*
