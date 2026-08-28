# CONTEXT.md — TEMPORARY, DELETE BEFORE MERGE

**This file is a session-handoff scratchpad. It must be removed before this PR merges.**
It exists only so a fresh Claude (Opus 4.8) chat on another machine can pick up where the last
one left off. It is not documentation. `git rm CONTEXT.md` before merge.

---

## What this PR is

Repo: `Quenty/NevermoreEngine` (this checkout is `D:\Source\Nevermore`).
Fork: `buildthomas/NevermoreEngine`. Branch: `users/buildthomas/fix-datastore-teardown-during-request`.
PR: **#784** — "fix(datastore): stop a stale lock locking a player out permanently".

Two commits (branch order):
- `f9ec95526d` fix(datastore): stop a save reporting theft over a lock the load would take
- `700fe11024` fix(datastore): survive a teardown that lands mid-request

The consuming game is `egg-hunt-2026` (sibling repo, `D:\Source\egg-hunt-2026`). It is built on the
Nevermore + Raven package ecosystems. `@quenty/datastore` is consumed as an npm package; production
runs whatever version the deploy's lockfile resolved.

## The production incident this fixes

Symptom: certain players kicked 1–2s after joining, on **every** join, message
**"DataStore session stolen by another active session. Please message developers."** Their
`PlayerData` key (datastore `PlayerData`, scope `SaveData_10` in prod, `SaveData_9` otherwise; key =
`tostring(userId)`) held a root-level `lock` field naming a session from a server that died hours-to-
days earlier. **Manually deleting only the `lock` field permanently fixes that player.** That single
fact is what localized the bug to the lock machinery.

Two composing defects:

1. **The kick (root cause) — lock-age asymmetry.** `DataStoreLockHelper.AcquireLock` (load path)
   treats a foreign lock older than `GetAutoSaveTimeSeconds() * UNLOCK_BY_DEFAULT_TIME_MULTIPLIER`
   (300 * 2.1 = 630s) as a crashed server's and steals it. `DataStoreLockHelper.ToUnlockedProfile`
   (save path) never consulted `LastUpdateTime` at all — ANY foreign `ActiveSession`, any age, →
   `isValid=false` → `SessionStolen` fires (`DataStore.lua`, the `_doDataSync` transform) →
   `PlayerDataStoreManager` kicks. So a foreign lock that survives a load is stealable on load and
   fatal on save. The kick tears the session down before the lock is rewritten/released, so it
   survives to the next join. Waiting cannot help — the save path has no notion of age.

   **Fix:** both halves now call a shared `DataStoreLockHelper._isLockStale(parsedLockData)`. Save
   validates a stale foreign lock instead of reporting theft; the subsequent save rewrites the lock
   as ours, so an affected key self-heals. Fresh foreign locks and locks with no `LastUpdateTime`
   still report theft (tests cover both).

2. **The persistence — teardown mid-request.** `DataStore` destroyed while an `UpdateAsync` is in
   flight raised out of its own transform:
   `Transform function error ...DataStore:696: attempt to call missing method 'AcquireLock' of table`.
   `Promise.spawn` (`src/promise/src/Shared/Promise.lua:78-84`) does `task.spawn` without retaining
   the thread, so cancelling the maid-held promise does NOT stop the call — Roblox invokes the
   transform anyway. By then `BaseObject.Destroy` (`src/baseobject/src/Shared/BaseObject.lua:39-42`)
   has run `setmetatable(obj, nil)` on the store AND its helper, so method dispatch on either raises
   and the raise aborts the write Roblox was about to commit. On the load path that kills the
   steal-write that would have replaced the stale lock; on the save path it silently drops staged
   data.

   **Fix (IMPORTANT — earlier version was wrong):** the guard must NOT be a method on the store,
   because post-Destroy `self:anything()` is the same crash. First attempt used
   `self:_getSessionLockingHelper()` — a method call — which just renamed the crash. Current code
   reads `self._sessionLockingEnabledHelper` as a RAW FIELD (safe on a metatable-less table) and
   treats `getmetatable(helper) == nil` as proof of teardown, cancelling via the transforms'
   existing `return nil` path. Both transforms (`_doDataSync` and `_promiseGetAsyncNoCache`) patched
   this way. Non-session-locked stores keep old behavior via the existing `promise:IsRejected()`
   check.

## Files changed on the branch (`git diff origin/main...HEAD`)

- `src/datastore/src/Server/DataStoreLockHelper.lua` — `_isLockStale`; `ToUnlockedProfile` stale
  branch; `AcquireLock` uses the shared predicate.
- `src/datastore/src/Server/DataStore.lua` — raw-field teardown guard in both UpdateAsync
  transforms; new `IsLoadPending()`.
- `src/datastore/src/Server/PlayerDataStoreManager.lua` — traceback `warn` when a store is removed
  with its first load still in flight (gated on that window).
- `src/datastore/src/Server/Mocks/DataStoreMock.lua` — `pcall`s the transform, records
  `_lastTransformError`, exposes `GetLastTransformError()` so a spec can tell an aborted write from a
  cancelled one.
- `src/datastore/src/Server/DataStore.SessionLock.spec.lua` — save-side stale/fresh/no-timestamp
  cases.
- `src/datastore/src/Server/DataStore.TeardownDuringRequest.spec.lua` (new) — destroy mid-load,
  mid-save, and no-lock-left-behind.

## How the analysis was verified

Two subagents (one re-derived the root cause from `origin/main`, one adversarially audited the
diff). The audit CAUGHT the method-vs-field bug in the teardown guard described above; it has been
fixed and the branch force-pushed. The staleness commit was found sound and regression-free (all
existing theft specs use fresh `os.time()` locks, so none regress). Join-time saver that trips the
kick within seconds was traced to egg-hunt's reconcilers: `EggHuntCodeAccessService`
(`:281`/`:303`), `EggHuntRefundHoldService` (`:128`), and chapter-receipt re-delivery — all
self-re-arming, which explains "consistently the same players."

## Open issues / still to do

1. **CI has never run on this PR.** `gh pr checks 784` → no checks; local `lint:luau`/test runner is
   broken on the origin machine (`rojo --version` panics on this checkout's aftman spec,
   `quenty/rojo@7.7.0-rc.1-quenty.4`, "missing field 'source'"). stylua + selene are clean; specs
   were hand-traced against the mock's blocking semantics only. **The suite must get a real CI run
   before merge** — the teardown spec especially.

2. **UNRESOLVED root-cause gap (the important one).** A race cannot explain a *100% consistent*
   per-player lockout, and we could not prove why the load's steal-write fails on every join for the
   affected accounts. What IS certain: the stored lock is foreign at save time, which is only
   possible if the load's write didn't land. The failure is INVISIBLE by design: the load resolves
   from INSIDE its transform (before commit), and any later failure lands in a `:Catch` guarded by
   `if loadPromise:IsPending()` — already false — and is discarded with no warn/log/reject.
   Proposed minimal follow-up (NOT yet in the PR): add an `else` that `warn`s the discarded error,
   no behavior change, so the next affected join finally names the failure (throttle? size? backend?
   aborted transform?). Consider adding this to the PR or as a sibling.

3. **Behavioral follow-ups flagged in the PR body, not fixed here:**
   - Load resolving before its write commits (the blindness above) — fixing means resolving after
     commit settles; a real behavior change, wanted Quenty's opinion first.
   - A theft-dropped save `return nil`s, which is a SUCCESSFUL no-op UpdateAsync — so
     `Save()`/`SaveAndCloseSession()` RESOLVE while data was dropped. Receipt processors
     (`PromiseGrantChapter`) and shutdown flushes believe writes landed that didn't. Plausibly how
     the lost chapter purchases happened (see support tools below).

4. **Design decision awaiting reviewer:** the fix loosens the save-side theft rule (symmetry). The
   alternative is keep the save strict and make the load guarantee it never leaves a foreign lock
   behind. Called out in the PR body; commits split cleanly if Quenty prefers.

5. **`min_account_age_gate`** (egg-hunt `src/scripts/Server/AccountAgeGate.lua`) was investigated as
   a suspect and ruled out (affected players are old accounts). Mentioned only so it isn't re-chased.

## Support tools built (in egg-hunt, `tools/support/`, UNTRACKED — not committed anywhere)

Open Cloud Standard DataStore API, stdlib-only Python 3.8, plan/apply pattern, backups,
`matchVersion`, userIds/attributes round-trip, read-back verify. Env:
`ROBLOX_OPEN_CLOUD_KEY`, `ROBLOX_UNIVERSE_ID` (universe id, NOT place id).
- `strip_session_lock.py <userid> [--apply]` — removes only `lock`. This is the live remediation;
  fixes affected players. Refuses locks younger than 630s without `--force`.
- `restore_chapter_access.py <userid> --from <json> [--apply]` — merges `ChapterAccess` purchase
  records; never overwrites existing without `--overwrite-conflicts`; validates hard.
- `overwrite_player_data.py <userid> --from <json> [--apply]` — full-key replace, for reproducing a
  broken account's state on a test account. `--strip-lock` for a control. userIds default to the
  TARGET, not the source.

Repro note: a planted stale lock alone does NOT reproduce on a clean join (the load steals it). To
reproduce the kick deterministically, get in-game first, THEN plant a foreign lock and wait for a
save.

## Conventions (IMPORTANT)

- **No AI/Claude attribution** in commits or PRs — no trailers, no footers, plain technical prose.
  This is a standing user preference; do not add them.
- Package is `--!strict`, stylua-formatted (`stylua.toml`), selene-linted. Repo mandates LF via
  `.gitattributes`; on Windows some files check out CRLF — normalize before stylua or every line
  reads as a diff.
- Run tests with `nevermore test --cloud` from repo root (local mode reports false passes). Specs
  live next to code as `*.spec.lua`; tear down `ServiceBag`/objects via a `setup()`/`destroy()` Maid.
