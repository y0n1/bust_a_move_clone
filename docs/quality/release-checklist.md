# Release Checklist — Bust-A-Move Clone

> **Owner:** Quality Engineer  
> **Use:** Every release candidate, before the PM cuts `release/x.y.z`, tags, and DevOps deploys.  
> **Companion:** [`test-strategy.md`](test-strategy.md), [`../ops/deployment.md`](../ops/deployment.md),
> [`../decisions/0001-gitflow-and-conventional-commits.md`](../decisions/0001-gitflow-and-conventional-commits.md)

---

## 0. Release identity

| Field | Value |
|-------|-------|
| Version | `X.Y.Z+N` |
| Candidate commit | `__________` |
| Release scope (tasks) | `#___`, `#___` |
| QE report | `docs/quality/reports/YYYY-MM-DD-vX.Y.Z.md` |
| Target deploy | GitHub Pages |

---

## 1. Pre-flight

- [ ] All release-scope tasks are **Done** and QE-verified **post-merge on `develop`**.
- [ ] `CHANGELOG.md` updated for every user-facing change.
- [ ] Version **derived from the Conventional Commits history** since the last tag
      (`git log --oneline $(git describe --tags --abbrev=0)..HEAD`) and bumped in
      `pubspec.yaml`.
- [ ] Release notes drafted in `docs/releases/release-notes/vX.Y.Z.md`.
- [ ] Rollback target identified (last known-good commit/tag).
- [ ] No open Critical/High defects in scope.

## 2. Build and CI

- [ ] `flutter analyze --fatal-infos` is clean.
- [ ] `flutter test test/` passes.
- [ ] Production build succeeds:
      `flutter build web --release --base-href /bust_a_move_clone/`.
- [ ] CI workflow is green on the candidate commit.
- [ ] Build artifact size is within budget.

## 3. Acceptance and regression

- [ ] Every acceptance criterion is mapped to evidence.
- [ ] Critical-path smoke suite passes (start → aim → fire → match → descend →
      win/lose → retry).
- [ ] Wall bounce, life loss, level transition, and restart verified.
- [ ] No regression in previously shipped behavior.
- [ ] Edge cases verified: empty/full board, simultaneous win/lose, rapid
      input, interrupted shots, resize.

## 4. Compatibility

- [ ] Chrome stable desktop.
- [ ] Firefox stable desktop.
- [ ] Safari 17+ desktop.
- [ ] Edge stable desktop.
- [ ] Chrome Android phone (touch).
- [ ] Safari iPhone (touch).
- [ ] Small (360×640) and large (1920×1080) viewports.
- [ ] Keyboard-only input.
- [ ] Resize and orientation change during play.

## 5. Accessibility

- [ ] Contrast ≥ 4.5:1 text, ≥ 3:1 UI.
- [ ] Bubble color has a redundant symbol/pattern cue.
- [ ] Focus order logical; focus visible.
- [ ] Semantics labels for score, level, lives, and primary actions.
- [ ] Text scales without clipping.
- [ ] `prefers-reduced-motion` respected.
- [ ] Touch targets ≥ 44×44 pt.

## 6. Performance

- [ ] 60 fps minimum during gameplay, pops, chains, and descent.
- [ ] Input-to-feedback < 100 ms.
- [ ] Cold load within budget.
- [ ] No long tasks > 200 ms during gameplay.
- [ ] No memory growth over a 10-minute session.
- [ ] Lighthouse scores recorded (performance, accessibility, best practices).

## 7. Deployment readiness

- [ ] `release/x.y.z` branch cut from `develop` containing only the version bump
      and `CHANGELOG.md`.
- [ ] `release/x.y.z` merged into `main` with a merge commit (not squash) and
      tagged `vX.Y.Z` on that merge commit.
- [ ] Deploy workflow is green on `main` after merge.
- [ ] `version.json` matches the release version.
- [ ] Production URL returns HTTP 200.
- [ ] Assets load with no 404s.
- [ ] No blocking console errors.
- [ ] Service worker updates to the new build.
- [ ] Rollback path verified with DevOps.
- [ ] `docs/ops/deployment-log.md` entry prepared.
- [ ] `main` **back-merged into `develop`**; `release/x.y.z` deleted.

## 8. Verdict

| Verdict | Meaning |
|---------|---------|
| **PASS** | All gates pass; release authorized |
| **CONDITIONAL** | Specific conditions documented, owner and deadline set; user accepts |
| **FAIL** | One or more blocking gates failed; release not authorized |

- [ ] **PASS**
- [ ] **CONDITIONAL** — conditions: `__________________________`
- [ ] **FAIL** — blockers: `__________________________`

QE: `__________`  Date: `__________`  
User risk acceptance (if CONDITIONAL/override): `__________`

## 9. Post-deploy

- [ ] Production smoke test passed.
- [ ] Deployment log updated.
- [ ] GitHub Release published with notes.
- [ ] Tag matches the deployed commit.
- [ ] Board tasks moved to **Done**.
- [ ] Any escaped defect has a follow-up task.
