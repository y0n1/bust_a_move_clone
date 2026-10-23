# Dependency Policy — Bust-A-Move Clone

> **Owner:** DevOps Engineer  
> **Task:** OPS-7 / [#85](https://github.com/y0n1/bust_a_move_clone/issues/85)  
> **Last verified:** 2026-10-23 (validated against `origin/develop` at `0c1299a`)  
> **Companions:** [`deployment.md`](deployment.md), [`branch-protection.md`](branch-protection.md),
> [`../agent-team.md`](../agent-team.md), [`.github/dependabot.yml`](../../.github/dependabot.yml),
> [`.github/workflows/dependency-review.yml`](../../.github/workflows/dependency-review.yml)

---

## 1. What is automated

| Mechanism | Ecosystem | When it runs | Defined by | Runs from |
|-----------|-----------|--------------|------------|-----------|
| Dependabot version updates | `pub` | Weekly, Monday | `.github/dependabot.yml` | **`main` only** |
| Dependabot version updates | `github-actions` | Weekly, Monday | `.github/dependabot.yml` | **`main` only** |
| Dependency review gate | whatever the dependency graph holds | Every PR to `main` and `develop` | `.github/workflows/dependency-review.yml` | the PR's **base branch** |
| Dependabot security updates | both | As soon as an advisory matches | repository settings — *not* a file | `main` |
| Dependency graph | `pub` | On every push — **currently disabled on this repository**, see §7.1 | GitHub, from the committed `pubspec.lock` | `main` |

Two of those rows are the reason this document exists at all:

**Dependabot version updates only run from the default branch.** The schedule is
read from `main`. A change to `dependabot.yml` merged into `develop` does nothing
until the release that carries it reaches `main` — so "Dependabot is configured"
means "configured, and armed at the next release", not "already opening PRs".

**The review gate runs on its own PR.** A workflow added in a pull request runs
for that pull request — observed on
[#104](https://github.com/y0n1/bust_a_move_clone/pull/104), where the
`dependency-review` job appeared alongside `analyze-test` and `build-web`. There
is no "wait for the next PR" gap: the gate either works the first time it is
exercised, or it fails there, visibly. On #104 it failed, and §7.1 is what it
said.

## 2. Cadence, and why

| Question | Answer | Reason |
|----------|--------|--------|
| How often? | Weekly, Monday | The project ships at human pace. Daily PRs would be noise; a month is too long a window for Actions, which are the only dependency that executes with a repository token. |
| Grouped? | One PR per ecosystem per week for minor + patch | Ungrouped, a project this size opens one PR per package and the queue becomes noise nobody reads — which fails exactly like having no automation. |
| Majors? | One PR each, never grouped | A major bump is a decision. It should arrive on its own where someone reads the changelog, not buried in a five-package routine PR. |
| Concurrency cap? | `open-pull-requests-limit: 3` per ecosystem | A cap turns "the bot is stuck" into a visible backlog instead of an unbounded queue. |
| Security updates? | Immediate, unscheduled | Security PRs ignore the schedule, the grouping and the PR limit. See §5. |

## 3. What the gate actually checks — and what it does not

`actions/dependency-review-action` diffs the dependency graph between the PR's
base and head revision and fails when the diff **introduces** something with a
known advisory.

**In scope**

- Dart packages in `pubspec.yaml` and `pubspec.lock`, direct **and** transitive —
  the lockfile is committed, so the graph sees the real tree.
- The actions referenced by the workflows, as `pkg:githubactions/…` purls.
- Licences, but only against an allow/deny list — see below.

**Not in scope — and this is the part that is easy to over-trust**

- **The Flutter SDK and the Dart SDK.** They are pinned by
  `FLUTTER_VERSION` in `.github/workflows/ci.yml`, not resolved by pub. No
  Dependabot ecosystem and no dependency-graph entry covers them; they move when
  a human bumps that pin (see `deployment.md` § *Bumping the toolchain*).
- **OS packages on the runner.** `ubuntu-latest` is a moving image; its contents
  are GitHub's problem, not this gate's.
- **Vulnerabilities that are already there.** The action compares two revisions.
  An advisory that matches a package already on `develop` produces no diff and
  therefore no failure. That case is covered by Dependabot **alerts**, not by
  this gate — which is why alerts stay on.
- **Licence enforcement, in practice.** The action's licence check is enabled by
  default, but it can only compare against an allow/deny list, and none is
  configured. So today a copyleft package would **not** fail the build. Adding an
  allow-list is a deliberate policy decision with a real false-positive cost; it
  is left as a follow-up rather than switched on silently. If you add one, put
  `allow-licenses` in the `with:` block of
  `.github/workflows/dependency-review.yml`, beside the other thresholds.

## 4. Triaging a Dependabot PR

1. **Read the diff, not just the title.** A grouped PR contains several bumps;
   the title only names the group.
2. **CI must be green.** `analyze-test` and `build-web` are the real proof — a
   dependency that breaks the release web build is exactly what `build-web`
   exists to catch.
3. **`pub` bump touching anything in `lib/`?** Run the release smoke suite
   before merging a major; minor/patch bumps rely on CI.
4. **`github-actions` bump?** Open the action's release notes and check for
   permission or runtime changes. A major can require a `permissions:` edit in
   the workflow that calls it — the bump alone will not tell you.
5. **Merge with a Conventional Commit** (`chore(deps): …` / `ci(deps): …` — both
   are pre-set in `dependabot.yml`), so the changelog stays derivable.
6. **Never mass-merge the queue.** Each PR is a decision.

**If one bump in a group is bad:** do not close the whole group. Close the group
with a comment naming the offending package, add an `ignore` entry for it, and
let the next scheduled run produce a clean group. Closing without a reason loses
the signal for the next person.

## 5. Security updates are not version updates

Security updates are a **repository setting**, not part of `dependabot.yml`. When
an advisory matches a dependency:

- a PR opens immediately, bypassing the schedule, the grouping and the limit;
- it is labelled as a security update by GitHub;
- it is **never** closed without a written reason in the PR body — either the
  advisory does not apply (say why) or the upgrade is being tracked elsewhere
  (link it).

## 6. When the gate fails

The failure names the advisory and, because `show-patched-versions: true` is set,
the first version that fixes it. In order of preference:

1. **Bump** to the patched version.
2. **Replace** the package, if no patched version exists.
3. **Allow** it with `allow-ghsas: [GHSA-…]` in the workflow's `with:` block —
   only with a linked issue explaining why the advisory does not apply, because
   the entry does not expire and will outlive whoever added it.

Thresholds are `fail-on-severity: moderate` and `fail-on-scopes: runtime`: a
low-severity advisory, or one that only affects a dev-only package, is reported
but does not block. Rationale is in the workflow comments.

## 7. Verification status — what is proven and what is not

| Claim | Status |
|-------|--------|
| `dependabot.yml` parses and matches the documented option names | ✅ validated locally before merge (a malformed file fails **silently**: no PRs, no red run) |
| `dependency-review.yml` parses and runs on a PR | ✅ observed on #104 — the job started and failed with an actionable message, not a YAML error |
| The gate can actually evaluate **this** repository | ❌ **BLOCKED** — the repository has no dependency graph. See §7.1 |
| Dependabot actually opens a PR on schedule | ⏳ **not yet proven** — the schedule is read from `main`, so the first real proof is the first Monday after this reaches `main` |
| The check blocks the merge button | ❌ **not yet** — a required status check is a repository setting. `dependency-review` is added to the proposal in [`branch-protection.md`](branch-protection.md) §3, which is not applied |

### 7.1 Blocker: this repository has no dependency graph

The action does not scan anything itself. It asks GitHub's dependency review API
to diff two revisions, and that API is unavailable here:

```console
$ gh run view --log-failed
##[error]Dependency review is not supported on this repository.
Please ensure that Dependency graph is enabled

$ gh api repos/y0n1/bust_a_move_clone/dependency-graph/sbom
{"message":"Not Found","status":"404"}

$ gh api repos/y0n1/bust_a_move_clone/dependency-graph/compare/develop...2d119b0
{"message":"Forbidden","status":"403"}

$ gh api repos/y0n1/bust_a_move_clone/dependabot/alerts
{"message":"Dependabot alerts are disabled for this repository.","status":"403"}
```

All of **Code security and analysis** is off for this repository: no dependency
graph, no Dependabot alerts, no Dependabot security updates, no secret scanning
(`security_and_analysis` in `GET /repos/{owner}/{repo}` reports every entry as
`disabled`).

**This cannot be fixed from a file.** Enabling the dependency graph is a
repository setting. It is also the *precondition* for three of this task's four
acceptance criteria, so OPS-7 is blocked on a settings change rather than on
code — recorded here instead of being papered over with a workflow that skips
itself when the graph is missing. A gate that silently no-ops is worse than no
gate, because it reports green.

Once the graph is enabled, re-running the job on any PR is enough; nothing in
this repository needs to change.

## 8. Files

| File | Role |
|------|------|
| `.github/dependabot.yml` | Schedule, grouping, commit prefixes, PR cap |
| `.github/workflows/dependency-review.yml` | The PR gate |
| `pubspec.lock` | Must stay committed — it is what makes the graph see the real tree |
| `.github/workflows/ci.yml` | Holds `FLUTTER_VERSION`, the pin that no bot manages |

## 9. Known gaps, recorded not hidden

- **Actions are pinned by tag (`@v4`), not by commit SHA.** Dependabot keeps the
  tag current, but a tag can be moved by its owner; a SHA cannot. SHA pinning is
  the stronger posture and is deliberately out of scope here — OPS-7 excludes
  mass changes, and SHA pinning is a repo-wide sweep.
- **No licence allow-list.** See §3.
- **The gate is not a required check.** See §7.
- **The dependency graph is disabled, so the gate cannot run at all.** See §7.1.
  Until that changes, the red `dependency-review` check on every PR is reporting
the repository's configuration, not the PR's dependencies.
