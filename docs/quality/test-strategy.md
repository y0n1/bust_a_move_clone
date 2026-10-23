# Test Strategy — Bust-A-Move Clone

> **Owner:** Quality Engineer  
> **Status:** Active (baseline established 2026-10-23)  
> **Companions:** [`release-checklist.md`](release-checklist.md), [`reports/`](reports/), [`../agent-team.md`](../agent-team.md), [`../architecture.md`](../architecture.md)

---

## 1. Purpose

Define how the team proves that a change is correct, that the game still feels
right, and that a release is fit for production. Quality is **verified against
the built artifact**, not just the development build.

## 2. Quality principles

- **Evidence over opinion.** Every verdict maps to a command, test, trace, or
  reproducible manual step.
- **Risk-based depth.** Spend the most effort where a defect hurts players
  most: engine rules, state transitions, and input.
- **Shift left, verify right.** Automate rules and regressions early; verify
  the deployed artifact before release.
- **Determinism.** Seeded randomness and fake clocks; no timing-dependent
  flake.
- **Independent judgment.** QE does not rubber-stamp a teammate's work.
- **Blameless defects.** Fix the system, not the person.

## 3. Risk model

| Area | Risk | Why it matters | Primary coverage |
|------|------|----------------|------------------|
| Hex-grid geometry & collision | **High** | A wrong snap or bounce makes the game unfair | Engine unit tests, boundary cases |
| Match-3, chain reactions, cluster drop | **High** | Core scoring loop; silent errors corrupt progression | Engine unit tests, seeded scenarios |
| Wall descent & loss condition | **High** | Wrong pacing or a false loss ends the run | Engine unit tests, regression suite |
| Lives, level, win/lose, restart | **High** | State corruption breaks the session | ViewModel tests, smoke suite |
| Aiming & input | **High** | Lost or inverted shots feel broken | ViewModel tests, manual, cross-input |
| Rendering, juice, HUD | **Medium** | Degrades clarity and delight | Widget tests, visual checks |
| Web loading & service worker | **Medium** | Blank page or stale build blocks everyone | Production smoke, update check |
| Accessibility | **Medium** | Excludes players; color-only cues fail | Manual audit, semantics tests |
| Performance | **Medium** | Jank ruins the arcade feel | Traces, Lighthouse, budgets |
| Multiplayer (future) | **High** | Fairness and trust | Protocol/replay/latency tests |

## 4. Test pyramid

| Layer | Scope | Location | Command | Runs |
|-------|-------|----------|---------|------|
| **Unit** | Engine rules, model invariants, ViewModel transitions | `test/engine_test.dart`, `test/descent_test.dart`, `test/gameplay/viewmodel/`, `test/start_screen/viewmodel/` | `flutter test test/` | Every PR |
| **Widget** | HUD, overlays, critical interactions | `test/gameplay/ui/` | `flutter test test/` | Every PR |
| **Integration / E2E** | Critical player journey on a built artifact | `test/quality/release_smoke.py` | `python3 test/quality/release_smoke.py` | Release candidate |
| **Manual exploratory** | Feel, clarity, delight, edge cases | Charter-based sessions | — | Release candidate |
| **Production smoke** | Deployed URL, assets, console, service worker | Live URL | Browser + `curl` | Every deploy |

## 5. Coverage map

| Area | Automated | Manual | Gate |
|------|-----------|--------|------|
| Engine rules | ✅ unit | Spot checks | CI |
| Descent/loss | ✅ unit | — | CI |
| Lives/level/restart | ✅ ViewModel | Smoke | CI |
| Aim/fire input | ✅ ViewModel | Mouse, touch, keyboard | Release |
| HUD/overlays | ✅ widget | Visual check | Release |
| Renderer/juice | Partial | Visual + fps | Release |
| Responsive layout | ❌ | Desktop + mobile viewports | Release |
| Cross-browser | ❌ | Chrome, Firefox, Safari, Edge | Release |
| Accessibility | Partial | WCAG 2.1 AA audit | Release |
| Performance | ❌ | Trace + Lighthouse | Release |
| Service worker | ❌ | Cold load + update | Release |

## 6. Environments

| Environment | Use | Notes |
|-------------|-----|-------|
| Local dev (`flutter run`) | Fast iteration | Never a release verdict |
| Local production build | Reproduce the Pages artifact | `flutter build web --release --base-href /bust_a_move_clone/` |
| CI | Automated gate | Analyze + tests |
| Production | Final verification | <https://y0n1.github.io/bust_a_move_clone/> |

Serve the production build locally with:

```bash
flutter build web --release --base-href /bust_a_move_clone/
rm -rf /tmp/bam-preview && mkdir -p /tmp/bam-preview
cp -r build/web /tmp/bam-preview/bust_a_move_clone
python3 -m http.server 8400 --directory /tmp/bam-preview
# http://localhost:8400/bust_a_move_clone/
```

Serve the artifact under a `bust_a_move_clone/` directory so the Pages base
href resolves; serving `build/web` at the root causes blank-page 404s.

`test/quality/release_smoke.py` does exactly this, then drives the result in
headless Chrome. It needs no Flutter VM service, no `chromedriver`, and no
Python packages beyond the standard library — it talks CDP over a WebSocket it
vendors itself. Add `--no-build` to re-use an existing `build/web`.

## 7. Browser and device matrix

| Platform | Minimum coverage | Coverage tier |
|----------|------------------|---------------|
| Chrome stable, desktop | Full smoke + gameplay | Tier 1 |
| Firefox stable, desktop | Smoke + gameplay | Tier 2 |
| Safari 17+, desktop | Smoke + gameplay | Tier 2 |
| Edge stable, desktop | Smoke | Tier 3 |
| Chrome, Android phone | Touch aim/fire, layout | Tier 1 |
| Safari, iPhone | Touch aim/fire, layout | Tier 2 |
| Small viewport (360×640) | Layout, hit targets | Tier 1 |
| Large viewport (1920×1080) | Layout, scaling | Tier 2 |

Also cover: device pixel ratio 1×/2×/3×, resize during play, orientation
change, and keyboard-only input.

## 8. Acceptance verification

For every task whose release reaches `main`:

1. Read the developer's **acceptance rubric** and the UX spec. The rubric is the
   contract; if it is missing or untestable, reject the task on that basis.
2. Map each rubric item to a test name, command, screenshot, or manual step, on
   `main` or on the deployed production build.
3. Verify positive and negative paths.
4. Check edge cases: empty/full board, simultaneous win/lose, life loss,
   level transition, restart, rapid input, interrupted shots, resize.
5. Record the verdict in `docs/quality/reports/` and on the task.

**Never verify on `develop` or on a task branch.** See
[ADR 0002](../decisions/0002-validate-on-main.md).

A handoff without a testable rubric is rejected.

## 9. Regression smoke suite

The critical journey must pass on every release candidate:

1. Start screen renders; PLAY starts a game.
2. Aim moves the guide; fire launches the projectile.
3. Wall bounce works; off-screen shots do not disappear incorrectly.
4. A match-3 pops and scores.
5. Chain reactions and detached-cluster drops behave correctly.
6. Wall descent advances; loss triggers at the correct row.
7. Lives decrement and level progression works.
8. Restart resets the session cleanly.
9. HUD shows score and level correctly.
10. No blocking console errors.

This suite is automated: `python3 test/quality/release_smoke.py` runs all ten
steps against a freshly built artifact and exits non-zero if any step fails. A
release candidate is not verified until it passes.

One step can report **SKIP** instead of PASS. The chain-reaction check depends
on the board volunteering two pops in a row, which the suite cannot force, so a
non-observation is reported loudly and exits zero rather than flaking a release
gate. **A SKIP is not a pass**: that item stays a manual check (§ below and
`release-checklist.md` §3).

**Scope of the automation.** The script drives the real built artifact in
headless Chrome and asserts on the HUD text the app publishes through Flutter
web semantics. That is enough for the journey, the state transitions and the
console, but not for everything the ten items name:

| Item | Automated to the level of |
|------|---------------------------|
| 2–3 | **Pointer input only.** Clicks across the playfield and at a shallow angle are accepted, no overlay appears, and the HUD stays readable. Nothing here proves a shot was launched — the projectile and the aim guide are canvas-only — and a shot that changed nothing observable would pass. Guide motion and bounce angles are not asserted. |
| 5 | A chain reaction, proven from the `COMBO ×N` HUD text — **when the board volunteers one**. A level 1 board descends on every shot, so a life is lost about every fourth shot and each loss rebuilds the board and zeroes the streak; the wait is too heavy-tailed to gate on, so a non-observation is a loud SKIP and the item stays manual in `release-checklist.md` §3. The detached-cluster **drop** half has no observable surface and is covered by engine unit tests. |
| 6 | A life was lost with the wall at the cannon line. The step observes the loss, not the row that caused it; the exact row is an engine unit test. |
| 7 | A life loss costs exactly one life and keeps the level. Level **progression** on a clear is covered by engine tests (`startLevel(level + 1)`); `GameViewModel.restart()`'s won branch has no ViewModel test yet. |

It also verifies a **local** reproduction of the Pages artifact, not the
deployed URL. Post-deploy verification against production is
[`release-checklist.md`](release-checklist.md) §9 and the
[deployment runbook](../ops/deployment.md).

## 10. Accessibility checklist

- [ ] Text contrast ≥ 4.5:1; UI contrast ≥ 3:1.
- [ ] Bubble color is never the only cue (symbol/pattern required).
- [ ] Keyboard-only play is possible where the spec requires it.
- [ ] Focus order is logical; focus is visible.
- [ ] Semantics labels exist for score, level, lives, and primary actions.
- [ ] Text scales without clipping.
- [ ] `prefers-reduced-motion` is respected.
- [ ] Touch targets ≥ 44×44 pt.
- [ ] No flashing content that violates WCAG thresholds.
- [ ] Screen-reader pass on the start screen and HUD.

## 11. Performance budgets

| Metric | Budget | Baseline (2026-10-23) |
|--------|--------|-----------------------|
| Frame rate | 60 fps minimum, 120 target | Not measured |
| Input-to-feedback | < 100 ms | Not measured |
| Cold time-to-interactive | ≤ 5 s on Fast 3G / mid-tier | Not measured |
| `main.dart.js` (gzip) | ≤ 0.75 MB | 0.54 MB |
| `canvaskit.wasm` (gzip) | ≤ 3.25 MB | 2.79 MB |
| `build/web` total | ≤ 45 MB | 40 MB |
| Long tasks during gameplay | None > 200 ms | Not measured |
| Memory growth (10-min session) | < 10% | Not measured |

## 12. Defect severity

**Severity is QE's scale and is not board priority.** The board uses P0–P2
(owned by the PM) for scheduling; defects use Critical→Low for how bad the
failure is. They answer different questions, and a defect can be Critical but
scheduled as P2.

| Severity | Definition | Release impact |
|----------|------------|----------------|
| **Critical** | Crash, blank page, data loss, unplayable | Blocks merge and release |
| **High** | Core loop broken or major regression | Blocks release |
| **Medium** | Degraded experience with a workaround | Release only with recorded user acceptance |
| **Low** | Cosmetic or minor | May ship; log for later |

Every defect includes environment, steps, expected/actual, frequency, and
evidence.

## 13. Determinism and test data

- Seed every random source; never use wall-clock time in engine tests.
- Prefer explicit board fixtures over random boards for rule tests.
- Use fake tickers/clocks for ViewModel timing.
- Quarantine flaky tests; file a root-cause task instead of ignoring them.
- Keep test runtime short: the PR gate should stay under 8 minutes.

## 14. Metrics

| Metric | Target |
|--------|--------|
| PR gate pass rate | > 95% |
| Flaky test rate | < 2% |
| Escaped Critical/High defects per release | 0 |
| Acceptance criteria mapped to evidence | 100% |
| Smoke suite duration | < 5 minutes |
| Release gate first-pass rate | > 80% |

## 15. Baseline — 2026-10-23

| Check | Result | Evidence |
|-------|--------|----------|
| Static analysis | ✅ clean | `flutter analyze --fatal-infos` — exit 0 |
| Test suite | ✅ 45 passing | `flutter test test/` — exit 0 |
| Production build | ✅ succeeds | `flutter build web --release --base-href /bust_a_move_clone/` — 14.4 s |
| Production availability | ✅ live | HTTP 200 in 0.32 s |
| Browser smoke | ✅ Chromium | Start screen → PLAY → game screen; no console errors |
| Version metadata | ✅ 1.0.0+1 | `version.json` |
| Artifact size | ✅ within budget | 40 MB total; 0.54 MB gzip JS |
| Cross-browser evidence | ❌ none | Not yet tested |
| Accessibility audit | ❌ none | Not yet performed |
| Performance trace | ❌ none | Not yet measured |
| E2E/smoke automation | ✅ automated | `python3 test/quality/release_smoke.py` — 9–10/10 steps, observed 12–101 s end to end (build included unless `--no-build`) |
| Release tag | ❌ missing | No `v1.0.0` tag |

Full report: [`reports/2026-10-23-v1.0.0-baseline.md`](reports/2026-10-23-v1.0.0-baseline.md).

The `E2E/smoke automation` row read ❌ at baseline and was updated the same day
when QE-1 landed. Every other row is the baseline as measured.

The smoke timing is a range, not a constant: the suite hunts for a match-3 and
for a chain reaction on an **unseeded** board, so how long it runs depends on
how quickly the board cooperates. A run that never sees a chain burns the whole
chain budget — 101 s end to end, the worst observed — so the shot count, not the
app, dominates the duration. The default budgets bound it at roughly 120 shots,
or about 150 s, well inside the script's own five-minute guard.

The chain hunt has its own 80-shot budget rather than sharing the 40 used for
the match-3 hunt: across nine runs the first chain arrived after 4, 8, 21, 24,
26, 29, 39, 59 and 77 shots, and a later run saw none in 80. That tail is not
something a fixed budget can tame — a level 1 board descends every shot, so a
life loss rebuilds the board and zeroes the streak about every fourth shot — so
the step reports **SKIP** instead of FAIL when the board does not cooperate. The
durable fix is a test-only, `--dart-define`-gated seed hook that lets the suite
build a board that chains on demand; that is production code, so it belongs to
the Flutter Developer, not to QE.

## 16. Improvement backlog

Proposals for user triage — not Ready tasks.

| ID | Improvement | Why | Suggested branch |
|----|-------------|-----|------------------|
| QE-1 | ~~Automate the release smoke path against `build/web`~~ — **delivered**, see §4 and §9 | Manual verification is easy to skip | `test/release-smoke` |
| QE-2 | Add coverage reporting and a threshold | Makes untested rules visible | `test/coverage-report` |
| QE-3 | Add an accessibility audit (axe + manual) | Color-only cues and focus gaps | `test/a11y-audit` |
| QE-4 | Add a performance trace + Lighthouse budget | Jank and load regressions are invisible | `test/perf-budget` |
| QE-5 | Add cross-browser CI (Chromium + Firefox) | One-browser confidence is false confidence | `test/cross-browser` |
| QE-6 | Add visual regression goldens for HUD/overlays | Protects the polish pass | `test/visual-regression` |
| QE-7 | Add a long-session memory check | Leaks surface after minutes, not seconds | `test/memory-soak` |
| QE-8 | Add service-worker update tests | Stale builds are a production risk | `test/sw-update` |
| QE-9 | Add deterministic replay/seed tests | Protects engine determinism | `test/deterministic-replay` |
| QE-10 | Add a bug regression template | Every fix gets a test | `docs/regression-template` |
