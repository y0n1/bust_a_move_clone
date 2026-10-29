# Service-Worker Update Path — Bust-A-Move Clone

How a new build reaches a player who already has the game open, what was
measured, and what `test/quality/sw_update_check.py` asserts.

Issue: **#76 (QE-8)**. Related: OPS-12 (#90), the follow-up update prompt
noted in §6.

---

## 1. The question

A deploy replaces the files on GitHub Pages. A player has the game open in a
tab. **Does that player ever get the new build?** Three things could deliver it:

1. a service worker that checks for a new build and prompts,
2. a normal reload that revalidates cached assets,
3. nothing — the player keeps the old build until they hard-reload.

The answer decides whether the team needs an in-app update prompt, and how long
a fixed bug can appear unfixed to a player who is actively playing.

---

## 2. What was measured

### 2.1 Flutter 3.47 ships a service worker that caches nothing

`flutter build web` emits `build/web/flutter_service_worker.js` — **784 bytes**.
Its entire body:

```js
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', async () => {
  await self.registration.unregister();
  const clients = await self.clients.matchAll({type: 'window'});
  clients.forEach((client) => client.navigate(client.url));
});
```

It installs, takes over, **unregisters itself**, and reloads every open window.
It caches no asset. It has no version manifest and no update-check endpoint.

This is a deliberate change in recent Flutter: the generated worker exists only
to *evict* the caching workers that older Flutter versions installed. A player
who ran an old build is migrated off the stale worker once, and from then on
there is **no service worker at all**.

The check confirms this in the browser: after boot,
`navigator.serviceWorker.getRegistrations()` returns `0` and
`navigator.serviceWorker.controller` is `null`.

**Consequence:** there is no out-of-band update channel. Nothing can tell an
open tab that a new build exists.

### 2.2 GitHub Pages caches everything for ten minutes

Measured against production (`https://y0n1.github.io/bust_a_move_clone/`) on
2026-10-23 with `curl -sI`:

| Asset | `cache-control` |
|-------|-----------------|
| `/bust_a_move_clone/` | `max-age=600` |
| `index.html` | `max-age=600` |
| `version.json` | `max-age=600` |
| `flutter_bootstrap.js` | `max-age=600` |
| `flutter_service_worker.js` | `max-age=600` |
| `main.dart.js` | `max-age=600` |

All six carry an `etag` and `last-modified`, so a revalidation *would* be cheap —
but for ten minutes after a response is stored, the browser does not revalidate
at all. It serves the stored copy without contacting the server.

Note that `version.json` and `flutter_service_worker.js` are cached for the same
ten minutes as the bundle. Even if the app polled `version.json` to detect a new
release, the poll would read a ten-minute-old answer.

---

## 3. The staleness window

Combining §2.1 and §2.2:

> **A client can serve a superseded build for up to 600 seconds after a deploy,
> and an already-open tab never updates itself.**

The window behaves like this:

| Player action | Inside 600 s of their last load | After 600 s |
|---------------|-------------------------------|-------------|
| Keeps the tab open | old build, forever | old build, forever |
| Normal reload (F5) | **old build** — served from cache, no network request | new build |
| Hard reload (Shift+F5) | **new build** | new build |
| New tab / first visit | new build | new build |

The "keeps the tab open" row is the important one: the ten-minute window only
starts when the player *reloads*. A tab left open overnight is on the old build
indefinitely, because nothing prompts it to reload.

The test measures the normal-reload row directly: after publishing build B, a
normal reload reports `transferSize: 0` for `main.dart.js` — the bundle was
served entirely from cache, with **no network request at all**, while the server
was already serving build B.

---

## 4. What the test asserts

`test/quality/sw_update_check.py` runs the whole update cycle in a real Chrome
against a local server that reproduces Pages' headers exactly
(`Cache-Control: max-age=600` on every response).

It stages the real `build/web`, publishes a second build mid-session by rewriting
`version.json` and appending a marker line to `main.dart.js`, then asserts:

| # | Check | Proves |
|---|-------|--------|
| 1 | Client starts on build A | the baseline is not already the new build |
| 2 | Normal reload inside `max-age` still serves A | **the staleness window is real** |
| 3 | Hard reload immediately serves B | the deploy landed and can be reached |
| 4 | Client starts on build A (fresh session) | the expiry phase starts clean |
| 5 | Normal reload after `max-age` expires serves B | **the window is bounded** |

Each check also reports what the *server* currently serves, read with
`cache: 'reload'` so it always goes to the network. Check 2 passing while the
server serves B is the exact statement "the deploy landed but the client cannot
see it".

**The whole cycle runs twice.** A cache that updates only once — updated on the
first cycle, then stuck — would pass a single-cycle test.

Build identity is the `decodedBodySize` of the document's **own**
`main.dart.js` load, taken from `performance.getEntriesByType('resource')`. A
`fetch()` from the test would be a *new* request and would report whatever the
cache serves at that moment, not the build the page actually booted from. The
first version of this test made exactly that mistake and reported a hard reload
as ineffective when it was not.

### Running it

```bash
flutter build web --release --base-href /bust_a_move_clone/
python3 test/quality/sw_update_check.py
```

Options: `--cycles` (default 2), `--wait` (boot timeout, default 45 s),
`--build-dir`, `--window-max-age`, `--chrome`, `--headed`, `--keep`.

Exit codes: `0` pass, `1` a named check failed, `2` could not run.

### Negative control

A check that cannot fail is not a gate. Setting `--window-max-age 0` makes the
server advertise no cache lifetime; check 2 then fails as it should, because the
client updates on a normal reload:

```bash
python3 test/quality/sw_update_check.py --cycles 1 --window-max-age 0
# [FAIL] 2. Normal reload inside max-age=0s still serves build A
#        client runs build B, wanted build A — the staleness window ... no longer holds
```

Run this after changing `PAGES_MAX_AGE_S`, or after a Flutter upgrade, to confirm
the test is still sensitive to the behaviour it claims to measure.

---

## 5. Limitations

- **The hard reload is emulated with `Network.setCacheDisabled`.** CDP's
  `Page.reload(ignoreCache: true)` is documented as "as if the user pressed
  Shift+refresh", but headless Chrome does not honour it: subresources still
  come from the HTTP cache and the reload is indistinguishable from a normal
  one. Disabling the cache for the duration of the load is what DevTools' own
  "Disable cache" checkbox does. It is *not* identical to Shift+Refresh in one
  respect — with the cache disabled the responses are not written back — so the
  test asserts only that a hard reload *reaches* build B, and the expiry phase
  covers the cache updating on its own.
- **The test does not use the deployed site.** It reproduces the headers
  measured in §2.2. If Pages' cache policy changes, `PAGES_MAX_AGE_S` must be
  re-measured and the test updated. The negative control in §4 exists for this.
- **A locally built bundle is used, not a real deploy.** Both builds come from
  one `build/web`; build B differs only by `version.json` and an appended marker
  line. That is enough to make the two bundles distinguishable byte-for-byte,
  which is all the assertions need, but it does not exercise a change in
  `main.dart.js` size.
- **`flutter build web` output is not committed**, so the test requires a build
  to exist. It is not wired into `ci.yml`: the `build-web` job produces the
  artifact, and adding this check there is worth doing but is not part of #76.
- **Not covered:** the behaviour of a player who had an *old Flutter* caching
  service worker installed. That migration path is one-shot, cannot be
  reproduced from a current build, and is exercised only by real users.

---

## 6. Follow-up

The measured behaviour justifies one product change:

> **Show an in-app prompt when a new build is available.**

Without it, the only way a player gets a fix is to hard-reload a page that never
tells them anything changed. Filed as a separate task; this document is the
evidence for it.

Design constraints for whoever picks it up, from §2:

- A poll of `version.json` is cached for the same 600 s as everything else, so
  the poll must bypass the cache (`cache: 'reload'` / `cache: 'no-store'`) or it
  will report stale data.
- The prompt cannot rely on a service worker: there is none.
- `version.json` already exists in the build output and carries
  `app_name`, `version` and `build_number`, so no new build step is needed.

---

## 7. Provenance

| Item | Value |
|------|-------|
| Measured | 2026-10-23 |
| Flutter | 3.47.1 stable (Dart 3.13.1) |
| Chrome | 155.0.8059.84 |
| `flutter_service_worker.js` | 784 bytes, self-unregistering |
| Pages cache lifetime | `max-age=600` on all assets |
| Worst-case staleness | 600 s after a reload; unbounded for an open tab |
