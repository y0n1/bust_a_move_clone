# QE-10 — Bug regression template trial

| Field | Value |
|-------|-------|
| **Task** | QE-10 / [#78](https://github.com/y0n1/bust_a_move_clone/issues/78) |
| **Owner** | Quality Engineer |
| **Purpose** | Execute the issue's test plan: *"Use the template on a real defect and confirm it captures enough to reproduce."* |
| **Subject** | Defect **D2** from [`../../design/specs/honest-shot-score.md`](../../design/specs/honest-shot-score.md) §1.2 |
| **Verdict** | Template **sufficient** after five gaps were closed — recorded in §4, fixed in the same PR |

---

## 1. Why this defect

The test plan says "a real defect". Inventing one would prove the template formats
nicely and nothing else, so the subject is a defect that **ships today at `v1.0.0`**
and that nobody has filed:

> **D2 — the score popup is never drawn.** The ViewModel animates its FX against a
> clock that grows quadratically, so every popup is already expired by the time the
> painter looks at it.

It was chosen over its two siblings deliberately. **D1** (the popup shows the running
total instead of the gain) is a one-line arithmetic bug — any competent report of it
would reproduce, so it tests nothing about the template. **D3** (the particle bursts
share D2's clock) is the same defect in a second place. D2 is the one where "enough to
reproduce" is genuinely at risk: a naive report — *"the score popup doesn't show up"* —
is unreproducible, because the popup **is** created, **is** in the list, and **is**
retired on a correct schedule. Only the paint is wrong.

## 2. The template, filled in

Copied from [`../bug-regression-template.md`](../bug-regression-template.md) §2 and
filled. Line references were re-verified against `develop` with `grep -n`, not copied
from the spec — see §4, gap **G5**.

```markdown
## Bug: Score popup is never painted — FX clock runs ~30x fast

**Severity:** High
<!-- High, not Critical: the core loop still plays. The popup is feedback, and its
     absence does not block a match, a pop or a descent. -->

### Environment
| Field | Value |
|-------|-------|
| Build version (`version.json`: `version`+`build_number`) | `1.0.0+1` |
| Deployed commit / Actions run | `6c21684` / deploy-pages run for `v1.0.0` |
| Where | production https://y0n1.github.io/bust_a_move_clone/ |
| Browser + version | n/a — reproduces in a headless ViewModel test |
| OS + device | n/a |
| Viewport (WxH) + DPR | n/a |
| Input | mouse (any shot that scores) |

### Steps to reproduce
1. Load the game and press PLAY on level 1.
2. Aim at a cluster of three or more same-coloured bubbles and fire.
3. Watch the impact point for the floating `+N` popup.

### Expected
A `+300`-style popup appears at the impact point, rises 30 dp and fades over 500 ms.

### Actual
Nothing is drawn. No popup, ever — not a flicker, not a partial frame.

### Reproducibility
- [x] Always (10/10 shots, fresh page load each time)
- [ ] Intermittent
- [ ] Once

### Evidence
- Screenshot / recording: none needed — the absence is total, and the cause is
  arithmetic rather than environmental.
- Console errors: none. This is the trap: a silent no-op logs nothing.
- Network failures: none.

### Suspected subsystem
- [x] `lib/gameplay/viewmodel/game_viewmodel.dart` — `_fxElapsedMs` (L49, L165)
- [x] `lib/gameplay/ui/renderer/bubble_renderer.dart` — the age guard (L259-260)

### Regression test to add
- **File:** `test/gameplay/viewmodel/game_viewmodel_test.dart`
- **Harness:** `testWidgets(...)` + `tester.pump(Duration(milliseconds: 16))` — **not**
  `test(...)`. `_onTick` is private and the `Ticker` is real, so only the widget
  binding can advance time. See §3.1.
- **Setup:** `Engine.forLevel(1, rng: math.Random(42))`; `GameViewModel(engine)`;
  `vm.init()`; `addTearDown(vm.dispose)`.
- **Action:** `await tester.pump(const Duration(milliseconds: 16))` sixty times.
- **Asserts:** `expect(vm.fxElapsedMs, inInclusiveRange(900, 1000))`.
  Wall time after 60 pumps of 16 ms is 960 ms, and the final tick reports a
  cumulative elapsed of 944 ms, so any FX clock that tracks wall time lands inside
  that window. **Measured today: `28 320`.**
- **Fails before fix because:** `_fxElapsedMs += elapsed.inMilliseconds` sums the
  Ticker's **cumulative** duration, so tick *n* contributes `16n` instead of `16`.
  Sixty ticks therefore give `16 × (0+1+…+59) = 28 320`, which is the exact value the
  probe returned. Not an estimate — arithmetic that matched to the millisecond.

### Fix verification
- [ ] Regression test fails on the unfixed commit and passes after the fix
- [ ] `flutter test test/` green (no other test regressed)
- [ ] `flutter analyze --fatal-infos` clean
- [ ] Manually re-ran the original steps on the built artifact
- [ ] QE verdict recorded in `docs/quality/reports/`
```

## 3. Could a developer reproduce from that alone?

**Yes — and I proved it rather than judging it.** The filled report above was turned
into a real test, run against `develop`, and it failed for the reason the report names:

```console
$ flutter test test/gameplay/viewmodel/_trial_scratch_test.dart
TRIAL fxElapsedMs=28320 expected~960
  Expected: be in range from 900 (inclusive) to 1000 (inclusive)
    Actual: <28320>
00:00 +0 -1: Some tests failed.
```

`28 320` is exactly `16 × (0+1+…+59)`, so the failure message alone identifies a
quadratic clock. The probe file was then **deleted** — it never ships, because a
test that fails on `develop` belongs in the fix PR, not in a documentation change.

Three things made the difference, and all three are template features rather than
author diligence:

1. **§4's "record ticks per shot"** turned a visual complaint into an arithmetic
   assertion. Without a pinned tick count this defect is unreproducible.
2. **§2's "Fails before fix because"** forced the quadratic sum to be written down,
   which is what proves the test fails for the *right* reason rather than because the
   fixture was wrong.
3. **§2's "File"** pushed the report toward a real file with a real harness — which
   is where the next finding came from.

### 3.1 The report had to correct the template on *how* to test this

The obvious instruction — "add a unit test to `game_viewmodel_test.dart`" — **does not
work**. That file uses plain `test(...)`, and the ViewModel exposes no way to advance
time:

```dart
Ticker? _ticker;                     // real Ticker, started in init()
void _onTick(Duration elapsed)       // private
```

So the only shape that can reach the FX clock today is a `testWidgets` test that pumps
the scheduler. That is a legitimate finding about the *code*, not the template: **a
defect in a private method behind a real `Ticker` is reachable only through the widget
binding**, and a report that says "write a unit test" would have sent the developer
into a dead end. The template now asks for the test's *harness*, not just its file.

## 4. Gaps the trial found

The template was usable but not sufficient. Each gap below was a real risk of an
unreproducible report, and each was fixed in this PR.

| # | Gap | Why it matters | Fix |
|---|-----|----------------|-----|
| **G1** | §4 (determinism) covered seeds, board parameters and shot sequence but **not clocks**. | D2 is a *time* defect. A seed does not reproduce it; only a tick rate and a tick count do. The section that exists to make bugs replayable was silent on the one axis this bug lives on. | §4 gained item **5, "Clock and tick rate"**, with D2 as the worked example. |
| **G2** | §3 (where the test goes) had no location for **renderer or painter** defects. | D2's sibling D3 is a painter bug. The template's answer was "widget test", but `CustomPainter` logic is testable without a widget tree, and the report should say where. | §3 now names `test/gameplay/ui/` for renderer and painter logic. |
| **G3** | The template claimed `test/gameplay/ui/` "exists but is **empty**" and that `test/gameplay/logic/` was empty too. **Neither directory exists** — not in the tree and not on disk; git does not track empty directories, so nothing ever created them. | A reader would create a file and be surprised by a missing directory, or worse, trust a claim that the repo was structured for tests it was not. | Both claims corrected to say the directories are **not in the tree** and the first test creates them. |
| **G4** | The Environment table had no way to say *"cannot apply"*. Every field was `___`. | A ViewModel bug has no browser, OS or viewport. Filling `___` makes the report look incomplete; deleting the rows silently drops evidence. Neither is honest. | §2 now defines **`n/a` = cannot apply** vs **`___` = not captured yet**, and forbids conflating them. |
| **G5** | The spec this defect came from cites `game_viewmodel.dart` **L103** and **L106**; the real lines are **L105** and **L110**. It also gives the popup age guard as **L259** when the guard is at **L260**. | Not a template gap — a reminder that **line references in a design document are claims, not evidence**. QE re-derived every one with `grep -n` before writing them into a defect. | Recorded here. The spec is a merged design artifact and is not edited from a QE task; the corrected numbers are in §2 above. |
| **G6** | §2 asked for a regression test's **file**, but not for the **harness** that makes the test possible. | For D2 the obvious answer — "unit test in `game_viewmodel_test.dart`" — is wrong, because that file uses plain `test()` and the FX clock is a private method behind a real `Ticker`. A report can name a perfect assertion and still leave the fixer unable to run it. | §2's "Regression test to add" now has a **Harness** line (`test` vs `testWidgets`, how time is advanced), and §3 says what to do when no harness can reach the code. |

## 5. What this trial does not prove

- **One defect is not a sample.** The template is validated for a ViewModel/clock
  defect. It has not been exercised on a Critical, a build/deploy defect, or a
  purely visual one, where the `n/a` convention is untested.
- **The probe was deleted, not shipped.** A test that fails on `develop` would turn
  the suite red for a defect that is nobody's current task. The assertion is
  specified in §2 and belongs in the fix PR; QE-10 is documentation.
- **D2 is still shipping.** The trial found and characterised it; nothing in this PR
  fixes it. It needs its own board task, and per
  [`../bug-regression-template.md`](../bug-regression-template.md) §1 it should be
  filed, prioritised by the PM and fixed with the test above.
