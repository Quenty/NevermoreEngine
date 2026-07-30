# Shutdown and session locks

Why [PlayerDataStoreManager] saves the way it does. Written for whoever changes this package next.
Consumers do not need any of it — using the manager correctly requires nothing from this file.

Read it before adding any cleanup, teardown, or flush to the save path. Two attempts at exactly that
regressed player data in production, in opposite directions, and both looked obviously correct.

## The engine behavior this rests on

Two facts about Roblox, neither of them discoverable from this package's code:

**A closing server fires `PlayerRemoving` for every player still in it**, and holds the shutdown open
for those handlers the same way it does for `BindToClose`. A restart is not a case where players
"never leave" — they all leave, then the server closes. So `PlayerRemoving` is the save path during a
shutdown, not a peacetime-only path that something else has to stand in for.

**A session lock can only be released by the server holding it.** Nothing gives one server the
authority to unlock another's key. If a server dies still holding a lock, the next server that loads
that key sees a lock that still looks live and takes the graceful route: it messages the holder's
JobId asking it to close, and that JobId is gone, so nothing answers.

The cost of that is worth knowing precisely, because the obvious knob is the wrong one. Each attempt
dies on the **hardcoded 5s timeout in `DataStoreMessageHelper.PromiseCloseSessionGraceful`**, not on
`SetSessionMessagingCloseDelaySeconds` — that delay sits in the *fulfilled* branch of
`_promiseGetAsyncNoCache` and is never reached when the holder is dead. Six attempts of that is 30s,
and `PromiseRetryUtils` adds five jittered inter-attempt waits totalling ~49s, so a player waits
roughly **80 seconds** before the lock is finally stolen. Turning `SetSessionMessagingCloseDelaySeconds`
down does not shorten it; the lever is that hardcoded 5.

## The shape

Everything converges on one function:

```
Players.PlayerRemoving ─┐
SessionStolen ──────────┤
SessionCloseRequested ──┼──► _removePlayerDataStore(userId)
PromiseSessionLockingFailed ─┤     removing callbacks
RemovePlayerDataStore ──┘          └─► SaveAndCloseSession()   -- writes data AND releases the lock
                                        └─► Destroy()          -- only after that write settles

BindToCloseService ────────► PromiseAllSaves()
                               removes anything left, then WAITS
```

`_removePlayerDataStore` is idempotent and order-independent: it returns early if the store is already
gone from `_datastores` or already `_removing`. So on a shutdown, whichever entry point reaches a given
player first performs the complete sequence and the others no-op. There is deliberately **no path that
destroys a store before its save-and-close has been attempted and settled** — note "attempted": the
`Destroy()` sits in a `Finally`, so a save that rejects still tears the store down.

That `Finally` has a second consequence worth knowing. `Promise.Finally` is `Then(f, f)` and `f`
returns nothing, so the derived promise *fulfills* even when the save rejected. `removalPromise`
therefore never rejects, and `PromiseAllSaves` resolving means every removal **settled**, not that
every write succeeded. It is the right shape for a shutdown — one player's failed write must not
abandon everyone else's — but do not read a resolved close as proof of a successful save.

`PromiseAllSaves` is a *waiter*, not a saver. `BindToCloseService` yields on it, which is the only
thing keeping the server alive long enough for the writes to land.

## What `PromiseAllSaves` has to wait on, and why it isn't obvious

It waits on the in-flight removal chains in `_removingPromises`, not only on `_pendingSaves`. This is
the part that actually loses live-server data, so it is worth following exactly.

`_pendingSaves` is fed by a `datastore.Saving:Connect` that lives on the per-user maid at
`self._maid._savingConns[userId]`. The last thing `_removePlayerDataStore` does is
`self._maid._savingConns[userId] = nil`, which cleans that maid and **disconnects `Saving`**. And
`DataStore` fires `Saving` at the very *end* of `_doDataSync` — after `PromiseViewUpToDate()` and after
every saving callback has resolved.

So the two only line up when the whole removal chain runs synchronously. The moment anything in it
yields — an async removing callback, an async saving callback, or a session-locked load still in flight
because the player left seconds after joining — `SaveAndCloseSession` reaches `Saving` *after* the
connection is already gone, and that save can **never** enter `_pendingSaves` at all. It is not a race
that usually goes the right way; it is a permanent miss.

The old `PromiseAllSaves` then had literally nothing to wait on: `PromiseUtils.all({})` returns an
already-fulfilled promise, `BindToCloseService` stops yielding, and Roblox kills the server mid-write —
leaving the session locked, with nobody able to release it, and the next server paying the ~80 seconds.
Any consumer with an async removing or saving callback hits this, which is most of them.

Waiting on `_removingPromises` fixes it because those entries are inserted synchronously by
`_removePlayerDataStore`, before anything can yield, and cleared in an identity-guarded `Finally` — so a
fast leave/rejoin cannot clobber the entry the close is waiting on.

## Rejected: flushing the stores on manager teardown

`_flushAndDestroyAll` existed for twelve days (added 2026-07-17, removed 2026-07-29) and was removed. It
ran from the manager's Maid and, for every store still in `_datastores`, saved and then destroyed it
synchronously.

It was added for a real reason — a `DataStore` starts a `task.spawn` auto-save loop once loaded and
only cancels it on `Destroy()`, so a manager torn down without destroying its stores leaks those loops
(which matters in the shared test place, where a leaked loop fires inside a later package's window).

It was wrong anyway, because **destroying the manager is not a shutdown.** No path in `ServiceBag`,
`BindToCloseService`, or any game in this repo destroys it on close; only a hot reload, a Studio stop, or
a test does. But wherever something did, the teardown got there before `PlayerRemoving`, cleared
`_datastores`, and destroyed the stores — so the removal that would have saved and closed the session
found nothing and returned early. Both flavors failed:

- With `Save()`, the data was flushed but the lock was never released, handing the next server the
  ~80-second ladder.
- With `SaveAndCloseSession()`, the lock was released, but the store was destroyed synchronously
  against its own in-flight write, and the session was closed while players were still in the server
  and still writing. Everything still holding the store wrote into a destroyed object:
  `attempt to call missing method 'GetSubStore'`, and consumers' own "datastore already cleaned up"
  guards firing on a loop for the rest of the shutdown window.

The lesson is narrow and worth stating plainly: **the leak was a test-harness problem and belonged in
the test harness.** `DataStoreTestUtils` now shuts a manager down the way Roblox does before tearing it
down (`promiseSimulatedShutdown`), which removes the stores through the real path and cancels their
loops as a side effect. Production code did not need a second save path, and could not safely have one.

## Deliberate: a removing callback that never resolves blocks its removal forever

There is no timeout on the removing callbacks, and that is the intended behavior, not an oversight. A
callback that never settles holds its removal open, so the save never happens and the lock stays held,
and Roblox tears the thread down at the shutdown cap. A timeout here would convert that into a silent
partial save on a cadence nobody chose — better to let the consumer's broken callback take the blame.

Be honest about the diagnostic, though: nothing here names the callback that hung. By the time the
removal is stuck, the callback has already *returned* (it handed back a promise that never settles), so
its frame is gone; the thread Roblox kills is `BindToCloseService`'s `:Yield()`. If chasing one of these
gets painful, the missing piece is a `task.delay` warn naming the still-pending userIds — not a timeout.

`PlayerDataStoreManager.RemovalCallbacks.spec.lua` characterizes it under "failure modes" so the
behavior is pinned rather than accidental.

Since `PromiseAllSaves` now awaits the removal chains, this is also a new source of shutdown latency,
and it is bounded and benign: `PromiseUtils.all` never short-circuits, so one stuck member delays the
close but cannot cancel or skip the others, and every other player's removal was already dispatched and
completes concurrently. Roblox's ~30s cap ends it either way. The likely trigger in practice is not a
hung callback but a contended session-locked load — a player who joined seconds before the shutdown can
hold the close for as long as the acquire ladder runs.

## Testing this

One consequence of dropping the flush: the `DataStore` instances are not owned by any maid (only
`_removePlayerDataStore`'s `Finally` destroys them), so **`manager:Destroy()` now destroys no stores.**
A harness that tears down by destroying a ServiceBag therefore leaves every loaded store alive with its
auto-save loop running — and a `PlayerMock` never fires the real `Players.PlayerRemoving`, so nothing
else removes them either. Any spec built that way has to shut down explicitly before it tears down.

Resist the urge to fix that by re-adding a destroy on the manager's maid. A destroy-only teardown is
worse than the leak: it would leave `_datastores` populated with destroyed stores, so a `PlayerRemoving`
arriving afterwards would call `SaveAndCloseSession()` on a nil metatable, and clearing `_datastores`
too would silently drop the save. The leak is a harness problem; keep the fix in the harness.

`manager:Destroy()` is not a shutdown and specs must not use it as one — several did, which is how the
teardown flush looked well covered while being wrong. Drive
`DataStoreTestUtils.promiseSimulatedShutdown(manager, userIds)` instead: it fires the removals, then
returns the promise `BindToCloseService` would yield on.

The assertion that matters is not "the data was saved" but "the data was saved *by the time the close
resolved*" — that is the difference between a server that shuts down cleanly and one that dies holding
a lock. `PlayerDataStoreManager.spec.lua`'s "does not resolve the close while a PlayerRemoving save is
still in flight" pins it, using an async removing callback to open the window.
