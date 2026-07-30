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
that key sees a lock that still looks live, and takes the graceful route: it messages the holder's
JobId asking it to close. That JobId is gone, so nothing answers, and it waits out
`SetSessionMessagingCloseDelaySeconds` (5s default) before retrying — six attempts, ~76 seconds,
against a holder that no longer exists — and only then steals the lock. The player waits through all
of it.

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
destroys a store without first saving and closing its session.**

`PromiseAllSaves` is a *waiter*, not a saver. `BindToCloseService` yields on it, which is the only
thing keeping the server alive long enough for the writes to land.

## What `PromiseAllSaves` has to wait on, and why it isn't obvious

It waits on the in-flight removal chains in `_removingPromises`, not only on `_pendingSaves`.

`_pendingSaves` is fed by the `DataStore.Saving` signal, which `_doDataSync` fires at the very *end* of
a sync — after `PromiseViewUpToDate()` and after every saving callback has resolved. So a removal
triggered moments earlier by `PlayerRemoving` can still be working toward its `UpdateAsync` while
`_pendingSaves` is empty. Waiting on that empty set means `PromiseUtils.all({})` resolves immediately,
`BindToClose` returns, and Roblox kills the server mid-write — leaving the session locked, with nobody
able to release it. The next server pays the 76 seconds.

Any consumer with an async removing callback or an async saving callback hits this, which is most of
them.

## Rejected: flushing the stores on manager teardown

`_flushAndDestroyAll` existed for about six weeks and was removed. It ran from the manager's Maid and,
for every store still in `_datastores`, saved and then destroyed it synchronously.

It was added for a real reason — a `DataStore` starts a `task.spawn` auto-save loop once loaded and
only cancels it on `Destroy()`, so a manager torn down without destroying its stores leaks those loops
(which matters in the shared test place, where a leaked loop fires inside a later package's window).

It was wrong anyway, because **destroying the manager is not a shutdown.** Nothing in a live server
destroys it; only a hot reload or a test does. But when something did, the teardown got there before
`PlayerRemoving`, cleared `_datastores`, and destroyed the stores — so the removal that would have
saved and closed the session found nothing and returned early. Both flavors failed:

- With `Save()`, the data was flushed but the lock was never released. Every restart handed the next
  server the 76-second ladder.
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

There is no timeout on the removing callbacks, and that is the intended behavior, not an oversight.
A callback that never settles holds its removal open, so the save never happens and the lock stays
held — and Roblox eventually cancels the thread and surfaces a stack trace pointing at the callback
that hung. That is the outcome you want: the consumer's bug is named, loudly, in the place it
happened. A timeout here would swallow it and convert a diagnosable hang into a silent partial save.

`PlayerDataStoreManager.RemovalCallbacks.spec.lua` characterizes it under "failure modes" so the
behavior is pinned rather than accidental.

## Testing this

`manager:Destroy()` is not a shutdown and specs must not use it as one — several did, which is how the
teardown flush looked well covered while being wrong. Drive
`DataStoreTestUtils.promiseSimulatedShutdown(manager, userIds)` instead: it fires the removals, then
returns the promise `BindToCloseService` would yield on.

The assertion that matters is not "the data was saved" but "the data was saved *by the time the close
resolved*" — that is the difference between a server that shuts down cleanly and one that dies holding
a lock. `PlayerDataStoreManager.spec.lua`'s "does not resolve the close while a PlayerRemoving save is
still in flight" pins it, using an async removing callback to open the window.
