# Design System — Bust-A-Move Clone

| Field | Value |
|-------|-------|
| **Status** | ready for dev (design artifact — not an implementation task) |
| **Owner** | UX Designer |
| **Task** | UX-1 / [#67](https://github.com/y0n1/bust_a_move_clone/issues/67) |
| **Board state** | Backlog at time of writing. This document is design research permitted before triage ([charter §14](../agent-team.md)); **no implementation may start until the task is Ready.** |
| **Scope** | Tokens, motion, HUD patterns, accessibility. No `lib/` changes. |

---

## 1. Current state inventory

Facts read from the working tree on 2026-10-23. `lib/gameplay/ui/renderer/bubble_renderer.dart`
**exists** on disk (it is imported by `game_screen.dart`).

| Source | What it defines today |
|--------|----------------------|
| `lib/main.dart` | `MaterialApp`, Material 3, `ColorScheme.fromSeed(seedColor: Color(0xFFE53935))` — the seed is *bubble red*, while the accent actually used everywhere is yellow. |
| `lib/start_screen/start_screen.dart` | Background `0xFF0B1E3A`; title `48/w700/0xFFFDD835/ls 4`; subtitle `16` + instructions `14`, both `0xFFB0BEC5`; padding `32`, gaps `12 / 48 / 24`; `FilledButton` `32×20`, label `20/w700`. |
| `lib/gameplay/ui/game_screen.dart` | Background `0xFF0B1E3A`. `_Hud` = `SafeArea(bottom:false)` + `EdgeInsets.fromLTRB(12,8,12,8)`. `_StatusOverlay` = scrim `Colors.black54`, `Card` `0xFF0B1E3A` `elevation 8` padding `32`, headline `32/w700/0xFFFDD835`, body `20`/`16` white, one `FilledButton`. `minViewportWidth 360` (L16) and `maxViewportWidth 1024` (L19) are declared and **never used**. |
| `lib/gameplay/ui/hud/score_display.dart` | `SCORE n` `18/w700/0xFFFFFFFF`; `COMBO ×n` `14/w700/0xFFFFB300`, rendered when `combo >= 2`. |
| `lib/gameplay/ui/hud/level_display.dart` | `LIVES` `16/w700/0xFFFDD835`; `LEVEL` `16/w700/0xFFB0BEC5`; `NEXT` `12/w700`; loaded bubble `28×28` + `0xFFFDD835` `2.5` border + `Icons.arrow_forward_ios` `14`; previews `18×18` + `Colors.white24` `1` border; gaps `12 / 16 / 8 / 4`; restart `IconButton` icon `18`. Holds **palette map #1** (L18). |
| `lib/gameplay/ui/renderer/bubble_renderer.dart` | **Palette map #2** (L88). Background `0xFF0B1E3A`. Bubble radius `bubbleSize*0.48`, highlight `withAlpha(160)` blur `2`, rim `black@40` `1` dp. Aim line `0x66FFFFFF` `2` dp, dash `0.15`. Cannon `0xFFB0BEC5` / `0xFF78909C`. Death line `0x33FF5252` `1` dp at `y = engine.rows`. Progress bar `80%` wide, `4` dp, `10` dp from bottom, track `0x33FFFFFF`, fill `0xCC66BB6A`, r `2`. Juice: `ScorePopup` 500 ms / rise 30 dp / `20/w700/0xFFFFD54F`; `ParticleBurst` 400 ms, 8 particles, r `0.15`; shake 200 ms ±2 dp; recoil 100 ms; `BIG POP!` 300 ms slide + 400 hold + 500 fade, `28/w700`. |
| `lib/gameplay/viewmodel/game_viewmodel.dart` | **Palette map #3** (L138). 60 Hz `Ticker`; FX ages accumulated in ms (`+16`/tick); no `Curve`, no named durations. `bubble` clamped `32`–`120` (L213). `minViewportWidth`/`maxViewportWidth` re-declared (L254/L257), **never used**. |
| `pubspec.yaml` | No `fonts:` and no `assets:` block — platform default typeface (Roboto on web), everything drawn with Canvas primitives. |
| **Missing entirely** | Pause state, sound, haptics, keyboard/focus handling, `Semantics` labels, reduced-motion support, colour-blind encoding. |

### 1.1 Baseline problems this system must fix

1. **No single source of truth** — 3 palette copies, background in 3 files, 8 ad-hoc font sizes (12/14/16/18/20/28/32/48), ad-hoc spacing (4/8/12/16/24/32/48).
2. **Motion is magic numbers** — 100/200/300/400/500 ms literals live inside the ViewModel and painter; no easing tokens.
3. **Palette fails WCAG** — purple `#8E24AA` is **2.37:1** on the surface (needs 3:1); death line **1.24:1**; progress track **1.88:1**. See §6.
4. **Colour is the only game channel**, and there is no non-pointer input, no reduced motion, no screen-reader output.

---

## 2. Design principles

| # | Principle | Implementation implication |
|---|-----------|---------------------------|
| 1 | **Clarity** — one obvious next action per state | Exactly one primary button per overlay; HUD carries four facts, no more; aim line appears the instant a pointer enters the playfield. |
| 2 | **Deference** — the board is the hero, chrome recedes | HUD is a single flat 56 dp row on `surfaceBase`; no card, no border, no gradient behind it; overlay cards appear only on win/lose. |
| 3 | **Depth** — layering explains cause and effect | FX render *above* bubbles and *below* HUD; the overlay sits above everything behind a scrim; z-order is fixed (§5.4), never ad-hoc. |
| 4 | **Restraint in motion** — animate meaning, not decoration | Every animation below has a named token and a reduced-motion fallback; nothing loops while idle; nothing exceeds 500 ms except the deliberate `BIG POP!` hold. |
| 5 | **Forgiveness** — never punish a mis-tap | ≥ 44 dp targets, ±3° keyboard aim step, aim clamped to ±60° (already in `updateAim`), every action cancellable (restart, pause, reduced-motion opt-out). |

---

## 3. Design tokens

Proposed home: **one** pure-Dart file `lib/design/tokens.dart` (no widgets, no `material.dart`
imports beyond `dart:ui` types) + `lib/design/bubble_style.dart` (enum → fill + symbol).
Deleting the three duplicated `_colors` maps is part of the implementation. *Ownership of
`lib/design/` is not yet assigned in the charter — see open question Q1.*

### 3.1 Colour

| Token | Dart name | Value | Contrast on `surfaceBase` | Use |
|-------|-----------|-------|---------------------------|-----|
| Surface base | `AppColors.surfaceBase` | `0xFF0B1E3A` | — | App background, board background, overlay card |
| Surface raised | `AppColors.surfaceRaised` | `0xFF132B4F` | — | Pause sheet, future settings panel |
| Scrim | `AppColors.scrim` | `0xB8000000` (72%) | — | Behind win/lose/pause overlay |
| On-surface primary | `AppColors.onSurface` | `0xFFFFFFFF` | 16.66:1 ✅ | HUD score, overlay body |
| On-surface secondary | `AppColors.onSurfaceMuted` | `0xFFB0BEC5` | 8.74:1 ✅ | Level, `NEXT`, instructions |
| On-surface tertiary | `AppColors.onSurfaceSubtle` | `0xFF78909C` | 4.97:1 ✅ | Captions, disabled labels |
| Accent | `AppColors.accent` | `0xFFFDD835` | 11.94:1 ✅ | Title, lives, overlay headline, focus |
| Accent warm | `AppColors.accentWarm` | `0xFFFFB300` | 9.28:1 ✅ | Combo chip |
| Positive | `AppColors.positive` | `0xFF66BB6A` | 4.99:1 ✅ | Progress fill |
| Danger | `AppColors.danger` | `0xFFFF5252` | 5.22:1 ✅ | Death line, lives-lost pulse |
| Warning | `AppColors.warning` | `0xFFFB8C00` | 7.02:1 ✅ | Reserved (bomb bubbles, future) |
| Aim line | `AppColors.aimLine` | `0x99FFFFFF` (60%) | 6.70:1 ✅ | Dotted aim guide |
| Progress track | `AppColors.progressTrack` | `0xFF52729E` | 3.38:1 ✅ | Level-progress bar background |
| Bubble rim | `AppColors.bubbleRim` | `0x28000000` (16%) | — | 1 dp inner edge on every bubble |
| Symbol ink | `AppColors.bubbleSymbol` | `0xE00B1E3A` (88%) | ≥ 3.46:1 on every fill ✅ | Shape cue inside bubbles |
| Focus ring | `AppColors.focusRing` | `0xFFFFFFFF` | 16.66:1 ✅ | 2 dp ring, 2 dp offset |

### 3.2 Bubble palette (maps 1:1 to `enum BubbleColor`)

| Enum value | Dart name | Fill | Symbol (shape cue) | Contrast on surface |
|------------|-----------|------|--------------------|---------------------|
| `BubbleColor.red` | `BubblePalette.red` | `0xFFE53935` | **×** cross | 3.94:1 ✅ |
| `BubbleColor.green` | `BubblePalette.green` | `0xFF43A047` | **▲** triangle | 5.04:1 ✅ |
| `BubbleColor.blue` | `BubblePalette.blue` | `0xFF1E88E5` | **▬** single bar | 4.53:1 ✅ |
| `BubbleColor.yellow` | `BubblePalette.yellow` | `0xFFFDD835` | **✦** four-point star | 11.94:1 ✅ |
| `BubbleColor.purple` | `BubblePalette.purple` | **`0xFFAB47BC`** (was `0xFF8E24AA`) | **◆** diamond | 3.46:1 ✅ (was 2.37:1 ❌) |
| `BubbleColor.orange` | `BubblePalette.orange` | `0xFFFB8C00` | **▪** square | 7.02:1 ✅ |

Symbol geometry: bounding box `0.42 × bubbleSize`, stroke `max(1.5, 0.055 × bubbleSize)`,
centred, `AppColors.bubbleSymbol`. Always rendered (see §6.2).

### 3.3 Typography

Family: `Roboto` (Flutter's default, already bundled — no new asset), fallback `['Inter', 'system-ui', 'sans-serif']`. HUD numerals use `FontFeature.tabularFigures()` so the score does not jitter while counting.

| Token | Dart name | Size | Weight | Letter-spacing | Height | Use |
|-------|-----------|------|--------|----------------|--------|-----|
| Display large | `AppType.displayLg` | 48 | `w800` | 4.0 | 1.0 | Start-screen title |
| Display medium | `AppType.displayMd` | 32 | `w800` | 1.5 | 1.1 | Overlay headline |
| Title large | `AppType.titleLg` | 28 | `w800` | 1.0 | 1.1 | `BIG POP!` banner |
| Title medium | `AppType.titleMd` | 20 | `w700` | 0.5 | 1.2 | Score popup, primary button label |
| Body large | `AppType.bodyLg` | 18 | `w700` | 0.5 | 1.3 | HUD score, tabular figures |
| Body medium | `AppType.bodyMd` | 16 | `w600` | 0.25 | 1.4 | HUD level/lives, instructions |
| Body small | `AppType.bodySm` | 14 | `w700` | 0.25 | 1.4 | Combo chip, secondary copy |
| Label small | `AppType.labelSm` | 12 | `w700` | 1.2 | 1.2 | `NEXT`, captions |

### 3.4 Spacing (4 pt scale)

| Token | Dart name | Value |
|-------|-----------|-------|
| 1 | `AppSpace.x1` | 4 |
| 2 | `AppSpace.x2` | 8 |
| 3 | `AppSpace.x3` | 12 |
| 4 | `AppSpace.x4` | 16 |
| 5 | `AppSpace.x5` | 24 |
| 6 | `AppSpace.x6` | 32 |
| 7 | `AppSpace.x7` | 48 |
| 8 | `AppSpace.x8` | 64 |

HUD gutter `x3` (12) compact → `x4` (16) medium → `x5` (24) wide. Overlay padding `x6` (32).

### 3.5 Radius

| Token | Dart name | Value | Use |
|-------|-----------|-------|-----|
| Extra small | `AppRadius.xs` | 2 | Progress bar |
| Small | `AppRadius.sm` | 8 | HUD chips |
| Medium | `AppRadius.md` | 12 | Buttons |
| Large | `AppRadius.lg` | 20 | Overlay card |
| Pill | `AppRadius.pill` | 999 | Combo chip |

Bubbles are always `BoxShape.circle` (no radius token).

### 3.6 Elevation

| Token | Dart name | Value (`BoxShadow`) |
|-------|-----------|---------------------|
| Flat | `AppElevation.e0` | none |
| Raised | `AppElevation.e1` | `Color(0x3D000000)`, blur `8`, offset `(0, 2)` |
| Overlay | `AppElevation.e2` | `Color(0x52000000)`, blur `16`, offset `(0, 6)` |
| Modal | `AppElevation.e3` | `Color(0x66000000)`, blur `32`, offset `(0, 12)` |

Overlay cards use `e3` (today: Material `elevation: 8`, ≈ `e2`).

### 3.7 Motion

| Token | Dart name | Value |
|-------|-----------|-------|
| Instant | `AppMotion.instant` | `Duration(milliseconds: 100)` |
| Fast | `AppMotion.fast` | `Duration(milliseconds: 120)` |
| Base | `AppMotion.base` | `Duration(milliseconds: 220)` |
| Slow | `AppMotion.slow` | `Duration(milliseconds: 320)` |
| Deliberate | `AppMotion.deliberate` | `Duration(milliseconds: 480)` |
| Standard | `AppMotion.standard` | `Cubic(0.2, 0.0, 0.0, 1.0)` |
| Enter (decelerate) | `AppMotion.enter` | `Cubic(0.0, 0.0, 0.2, 1.0)` |
| Exit (accelerate) | `AppMotion.exit` | `Cubic(0.4, 0.0, 1.0, 1.0)` |
| Emphasis (overshoot) | `AppMotion.emphasis` | `Cubic(0.34, 1.56, 0.64, 1.0)` |
| Chain stagger | `AppMotion.stagger` | `Duration(milliseconds: 60)` |

Reduced-motion gate (single helper, used by every animation above):
`MediaQuery.maybeDisableAnimationsOf(context) ?? false`; when true, replace each duration
with `AppMotion.fast` **and** drop translate/scale/rotate components (opacity only).

---

## 4. Motion spec

| # | Element | Trigger | Duration | Easing | Reduced-motion fallback |
|---|---------|---------|----------|--------|-------------------------|
| 1 | Aim line reveal | Pointer enters playfield | `fast` 120 ms | `enter` | Appear instantly, same alpha |
| 2 | Aim line track | Pointer move | **0 ms** (direct manipulation) | — | Unchanged |
| 3 | Cannon recoil | `fire()` | `instant` 100 ms, offset 0 → 2 dp → 0 | `standard` | No recoil |
| 4 | Projectile travel | `fire()` | Gameplay-driven, `projectileSpeed` 0.6 board-units/tick @ 60 Hz | linear | **Never reduced** — it is the game |
| 5 | Projectile trail | While in flight | 3 ghosts, alpha ≤ 60% | — | Trail hidden |
| 6 | Bubble settle | Projectile attaches to board | `fast` 120 ms, scale 1.10 → 1.00 | `emphasis` | Instant |
| 7 | Bubble pop | Match ≥ 3 | `base` 220 ms, scale 1.00 → 0.55, alpha 1 → 0 | `exit` | Instant removal |
| 8 | Chain link | Each subsequent pop | `base` 220 ms, delayed by `stagger` 60 ms per link | `exit` | No stagger |
| 9 | Detached cluster fall | After pop resolves | `slow` 320 ms, translate +1.5 board-heights, alpha → 0 in last 40% | `exit` | Instant removal |
| 10 | Wall descent | Every `descentInterval` shots | `base` 220 ms, translate +1 row | `standard` | Instant snap (fairness beats feel) |
| 11 | Score popup | Pop resolves | 500 ms, rise 30 dp, fade in last 40% | `exit` | `base` 220 ms fade in place |
| 12 | Particle burst | Pop resolves | 400 ms, 8 particles, outward 0.02–0.05 units/tick | linear | Suppressed |
| 13 | `BIG POP!` banner | `poppedThisShot >= 5` | `slow` 320 ms slide-in + 400 ms hold + 500 ms fade | `enter` then linear | `fast` 120 ms fade, 600 ms hold, no slide |
| 14 | Screen shake | `poppedThisShot >= 4` | 200 ms, ±2 dp | linear decay | Suppressed entirely |
| 15 | Combo chip appear | `combo >= 2` | `fast` 120 ms fade + 4 dp rise | `enter` | Instant |
| 16 | Progress fill | Bubble count changes | `base` 220 ms width tween | `standard` | Instant |
| 17 | Start → game | `PLAY` pressed | `slow` 320 ms cross-fade + scale 0.98 → 1.00 | `standard` | `fast` 120 ms fade |
| 18 | Overlay in | `status != playing` | `base` 220 ms scrim fade + card scale 0.94 → 1.00, y 8 → 0 | `enter` | `fast` 120 ms fade only |
| 19 | Overlay out | Restart / continue | `fast` 120 ms fade | `exit` | Instant |
| 20 | Lives lost | Status → `lost` | `base` 220 ms chip pulse to `danger` and back | `standard` | Colour change only |

Deltas from today: recoil 100 ms and shake 200 ms are already correct and become tokens.
`BIG POP!` slide moves 300 → 320 ms and swaps `easeOutQuad` for `AppMotion.enter`
(near-identical curve, now named). Popups, bursts, and pop now share one timeline instead
of three unrelated literals.

---

## 5. HUD patterns

### 5.1 Top bar anatomy

Single flat row on `surfaceBase`, height **56 dp** (compact) / **64 dp** (medium+),
inside `SafeArea(bottom: false)`, horizontal gutter per §5.3 (`x3` / `x4` / `x5`).

| Zone | Anchor | Contents | Rules |
|------|--------|----------|-------|
| Score cluster | start | `SCORE 1 240` (`bodyLg`, `onSurface`, tabular) over `COMBO ×3` chip (`bodySm`, `accentWarm`, `radius.pill`) | Combo chip occupies reserved space so the bar never reflows |
| Spacer | — | — | Absorbs all slack |
| Stats cluster | end | `LIVES 3` (`accent`) · `LEVEL 2` (`onSurfaceMuted`) · `NEXT` + queue · restart icon | Groups separated by `x3`, elements by `x2` |
| Restart | end | 44 × 44 target, 20 dp icon, `onSurfaceMuted` | Only icon-only control; must carry `tooltip` + `Semantics` label |

NEXT queue: loaded bubble `28 dp` with `2 dp` `accent` ring; previews `18 dp` with
`1 dp` `0x3DFFFFFF` ring; `4 dp` between items; **each preview draws its bubble symbol**.
Queue length: 2 compact, 3 medium+.

### 5.2 Overlay pattern (won / lost)

`scrim` → card (`surfaceBase`, `radius.lg`, `elevation.e3`, padding `x6`, max-width
`360` compact / `420` wide, centred) → headline (`displayMd`, `accent`) → stat line
(`titleMd`, `onSurface`) → one optional sub-line (`bodyMd`, `onSurfaceMuted`) →
**one** `FilledButton` (`titleMd`, min height `48`).

Copy: `LEVEL n CLEARED!` / `GAME OVER`; button `CONTINUE` (won, or lost with lives left) /
`PLAY AGAIN` (lost, no lives). Exactly one primary action — no secondary, no close icon.

### 5.3 Responsive rules

| Breakpoint | Width | HUD height | Gutter | NEXT previews | Type scale | Board |
|------------|-------|-----------|--------|---------------|-----------|-------|
| Compact | 360–599 | 56 | `x3` (12) | 2 | `bodyMd` labels | Full width, `bubbleSize` clamped 36–120 |
| Medium | 600–1023 | 64 | `x4` (16) | 3 | `bodyLg` score | Full width |
| Wide | ≥ 1024 | 64 | `x5` (24) | 3 | `bodyLg` score | Content column max **1024**, centred; board letterboxed |
| Short | height < 520 | 48 | `x3` | 1 | `bodyMd` | Board takes remaining height; overlays scroll |

Orientation is free — the board scales to fit the shorter axis (`computeLayout` already does this). Raise `minBubbleSize` 32 → **36** so the `0.42 × bubbleSize` symbol stays ≥ 15 dp. Below 360 dp the app is unsupported (declare it; do not reflow below that).

### 5.4 Z-order (fixed)

`surfaceBase` → death line → progress bar → bubbles → projectile + trail → particles →
score popups → `BIG POP!` banner → HUD bar → scrim → overlay card.

### 5.5 State inventory

| State | Trigger | Player sees | Primary action |
|-------|---------|-------------|----------------|
| Playing (idle) | Level start | Board, HUD, no aim line | Move pointer / tap |
| Aiming | Pointer in playfield | Dotted aim line from cannon | Release / tap |
| Firing | `projectile != null` | Moving bubble + 3-ghost trail, cannon recoiled | Wait (input locked) |
| Resolving | Pop chain in progress | Pops, particles, popups, optional shake/banner | Wait |
| Won | Board empty | Scrim + `LEVEL n CLEARED!` | `CONTINUE` |
| Lost (lives left) | Wall reaches cannon | Scrim + `GAME OVER` + `You have n lives left` | `CONTINUE` |
| Lost (no lives) | `lives == 0` | Scrim + `No lives remaining` | `PLAY AGAIN` |
| Paused / loading / error | **Do not exist.** No pause in `GameStatus` (Q3); web loading is Flutter's own bootstrap; the build is fully client-side, so offline == load failure | — | — |

---

## 6. Accessibility (WCAG 2.1 AA)

### 6.1 Contrast

Text targets ≥ 4.5:1; graphical objects and UI components ≥ 3:1 (SC 1.4.3, 1.4.11).
All ratios below are computed against `surfaceBase #0B1E3A` (relative luminance 0.0130).

| Item | Ratio | Verdict | Action |
|------|-------|---------|--------|
| Text tokens: `onSurface` #FFFFFF / `onSurfaceMuted` #B0BEC5 / `onSurfaceSubtle` #78909C | 16.66 / 8.74 / 4.97 | ✅ | — |
| Text tokens: `accent` #FDD835 / `accentWarm` #FFB300 | 11.94 / 9.28 | ✅ | — |
| Bubble red #E53935 | 3.94:1 | ✅ | — |
| Bubble green #43A047 | 5.04:1 | ✅ | — |
| Bubble blue #1E88E5 | 4.53:1 | ✅ | — |
| Bubble yellow #FDD835 | 11.94:1 | ✅ | — |
| Bubble orange #FB8C00 | 7.02:1 | ✅ | — |
| **Bubble purple #8E24AA** | **2.37:1** | ❌ | **Change to #AB47BC → 3.46:1** |
| **Death line #33FF5252** | **1.24:1** | ❌ | **Use opaque #FF5252 → 5.22:1, plus dashes** |
| **Progress track #33FFFFFF** | **1.88:1** | ❌ | **Use #52729E → 3.38:1** |
| Aim line #66FFFFFF | 3.73:1 | ⚠️ marginal | Raise to #99FFFFFF → 6.70:1 |
| Progress fill #CC66BB6A | 4.99:1 | ✅ | Make opaque `positive` |

### 6.2 Colour-blind safety (SC 1.4.1 — never hue alone)

Bubble luminance is nearly flat — green/blue are **1.11:1** against each other, red/orange
**1.78:1** — so no palette tweak can make hue sufficient. Every bubble therefore carries a
**shape cue** drawn in `bubbleSymbol` ink (§3.2), at all times, in the board, the projectile,
the trail, the cannon preview, and the NEXT queue. Six distinct silhouettes: `× ▲ ▬ ✦ ◆ ▪`.
Do **not** ship a toggle that hides them.

### 6.3 Reduced motion

Honour `prefers-reduced-motion` via `MediaQuery.disableAnimations` /
`PlatformDispatcher.accessibilityFeatures.disableAnimations`. When set: no shake, no
trail, no particles, no slide/scale — opacity only, and the fallbacks in §4 apply.
Projectile travel, wall descent *position*, and pop *removal* are never suppressed
(they are state, not decoration).

### 6.4 Targets, keyboard, semantics

- **Targets:** ≥ 44 × 44 dp for restart, overlay button, and any future HUD control.
  Bubbles are not tappable; the whole playfield is the aim surface.
- **Pointer:** pointer-move aims, pointer-down aims, pointer-up fires (existing behaviour).
  Add: pointer-down outside ±60° clamps (already in `updateAim`) and a `pointercancel`
  that cancels instead of firing.
- **Keyboard:** `Tab`/`Shift+Tab` across PLAY, restart, overlay button; `Enter`/`Space`
  activates; `←`/`→` aim ±3°; `↑`/`↓` fine-tune ±1°; `Space` fires when the board has focus;
  `Esc`/`P` pauses. Focus ring = 2 dp `focusRing`, 2 dp offset, always visible on `:focus-visible`.
- **Screen reader:** `Semantics` on the score (`'Score 1240'`), lives, level, and status;
  `liveRegion: true` on the score and on the win/lose headline; label the restart button
  `'Restart level'`; give the board a summary label (`'Level 2, 34 bubbles remaining'`).
- **Text scaling:** clamp HUD text to 1.3× (`MediaQuery.textScalerOf`) to prevent overflow;
  overlay cards scroll rather than clip at ≥ 1.3×.

---

## 7. Open questions

| # | Question | Needed from |
|---|----------|-------------|
| Q1 | Where do shared tokens live? Charter gives the Flutter Developer `lib/gameplay/ui/`, `lib/start_screen/`, and ViewModels — `lib/design/` is unassigned. Approve the path or name one. | User / PM |
| Q2 | Adopt a display font (e.g. Inter, Outfit) or stay on bundled Roboto? A font asset adds ~40–90 KB to the web bundle and requires a `fonts:` block in `pubspec.yaml`. | PM + Flutter Developer |
| Q3 | There is no pause state in `GameState`/`GameStatus`. Do we add one (`GameStatus.paused`) — engine change — or ship pause as a ViewModel-only overlay that stops the ticker? | Engine + Flutter Developer |
| Q4 | Is `#AB47BC` acceptable as the new purple, or is `#B388FF` (6.25:1, more violet, further from blue) preferred for art direction? | PM |
| Q5 | Sound/haptics are in the spec but absent from the build. Should the sound/haptic map be authored now (as a §3.7-style table) or deferred to the audio feature? | PM |
| Q6 | Does `minBubbleSize` 32 → 36 risk board overflow on 360 dp? `cols = 9` → 324 dp at 36, fits; confirm with the Flutter Developer against the level table. | Flutter Developer |
| Q7 | Is the 1024 dp max content width right for ultrawide desktop, or should the board keep scaling past it? | PM |
