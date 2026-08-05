# ClientTranslator design

Why the translation stack is shaped the way it is. Written for whoever changes this package next;
consumers do not need any of it. What a game developer acts on lives in
[`docs/gotchas/localization.md`](../../../docs/gotchas/localization.md) at the repo root.

The engine behavior this design rests on is written down separately in
[`engine-behavior.md`](engine-behavior.md); read that first if anything here looks arbitrary.

## The shape

```
JSONTranslator          per-translator: owns a loader, resolves text for a key
  |
  +-- InstanceLocaleLoader / TableLocaleLoader
  |     decode JSON -> queue entries (never writes the table itself)
  |
  +-- TranslatorService (shared, one per realm)
        owns the LocalizationTable, batches writes, tracks per-key readiness,
        resolves the current locale and the Roblox translators
```

Loaders only ever *queue*. Everything that touches the `LocalizationTable` goes through
`TranslatorService`.

## One table per realm, and what that costs

`TranslatorService.GetLocalizationTable` names the table by realm — `GeneratedJSONTable_Server` on
the server, `GeneratedJSONTable_Client` on the client — both under `LocalizationService`. They were
a single `GeneratedJSONTable` until `c1a7b0a` (2023), whose message says only "fix localization
table replication". The failure it removes is visible in the shape it replaced: with one name the
server created the table, it replicated, and the client then wrote its own entries into a
server-owned instance — writes that stay local, and that the server's next `SetEntries` re-
replicates the whole entry list over.

The consequence is easy to miss, because nothing in the API hints at it. `ToTranslationKey(prefix,
text)` returns a key **and registers `text` as that key's source** — into the table of the realm it
ran on. A key minted on the server therefore reaches the client with nothing behind it. The
client's table never saw the source, and the cloud translator does not know keys registered at
runtime either, so `_doTranslation` falls through every translator and returns the key, which is
what the player reads. Nothing corrects it later: there is no translation on its way.

**So mint on the realm that renders.** Send the authored text (or the prefix and text) rather than
only the key, and let the reading realm call `ToTranslationKey` or `ObserveTranslation` — since
registration is a side effect of minting, one call does both, and the derivation is deterministic
so both realms land on the same key. The server may keep minting its own copy for the CSV export;
the two registrations are the same entry with the same source.

## Writes are batched, and that is not negotiable

Every mutating call to a `LocalizationTable` — `SetEntries` and `SetEntryValue` alike — invalidates
the engine's cached table contents, raises a property change, and fires its retranslation signal. A
game streaming in registers thousands of entries in a single frame, so writing per entry is a
frame-killer. `TranslatorService` accumulates deltas and applies them **once per frame**, via
`task.defer`.

`TranslatorService.spec.lua` ("write cost while streaming in") pins this: the write count is `1`
whether ten or five hundred entries register in the frame. If a change makes that number scale with
entry count, the change is wrong, however clean it looks.

The cost of batching is that **a key is not readable the instant it is registered**. Everything
under "Readiness is per key" exists to pay that cost without giving up the batching.

### Two write regimes, chosen by batch size

Batching alone is not enough, because `SetEntries` is not free either: it re-serializes **every**
entry in the table. Once a game's table holds thousands of entries, rebuilding all of them so that
one newly-shown label can register its key is its own frame cost — and that is the steady state,
since text appearing on screen is what registers keys.

So a flush picks:

| Batch | Route | Why |
|---|---|---|
| Small relative to the table | one `SetEntryValue`/`SetEntryExample` per changed field | a few invalidations, nothing re-serialized |
| Large relative to the table | one `SetEntries` | one invalidation instead of hundreds, at the price of one rebuild |

The crossover is `INVALIDATION_ENTRY_COST` in `TranslatorService`: an invalidation is treated as
costing about as much as re-serializing 100 entries. It is a judgment call about the ratio of two
engine-internal costs, not a measured constant — tune it if the profile says otherwise, but keep
both regimes. Loading a locale (hundreds of entries at once) must not become hundreds of
invalidations, and showing one label must not rebuild the whole table.

Pinned by "lands a later handful of keys without rebuilding the whole table" and "rebuilds rather
than writing hundreds of entries one at a time", via `GetLocalizationRebuildCount`.

The targeted route trusts each call to leave the rest of the entry alone, and source and context
ride along only on a value write that actually changes a value — a `SetEntryValue` that rewrites the
text a locale already holds lands nothing, new metadata included. So a batch that changes nothing
but an entry's metadata is rebuilt rather than written. That is rare next to the value writes this
path exists for, and the alternative is a metadata change that silently does not land. What the
engine does and does not guarantee here is written up in
[`engine-behavior.md`](engine-behavior.md), pinned by "LocalizationTable behavior the targeted
writes rest on" and "queues a write that changes only the source or context".

### Registering unchanged text is free

`ToTranslationKey` registers its source text as a side effect of minting the key, so **every** label
built through `ObserveTranslation` re-registers text the table already holds. Queuing those would
schedule a flush, take the key not-ready, and drive a re-translation pass through every reader of
it — per label, per frame, in the source language, where there is nothing to translate at all.

`SetEntryValue`/`SetEntryExample` therefore drop a write the table already agrees with before it
queues. Source and context count as part of the value: a change in either still writes.

### The table is mirrored

Deciding any of the above means knowing what the table currently holds, and `GetEntries` copies and
re-materializes every entry in it — an O(table) read per flush, which is the cost being avoided.

So `TranslatorService` keeps a mirror of each table's entries, built once and kept in step with
every write. It is keyed by the `LocalizationTable` instance (weakly) and **shared across
`TranslatorService` instances**, because the table itself is shared: it is found by realm-scoped
name, so a second service bag in the same realm — a story, a test — writes into the same instance,
and a per-service mirror would go stale behind it.

A mirror that disagrees with the table fails silently and permanently: a write the mirror thinks is
already there is dropped, so the key never lands and nothing says so. Targeted writes cannot cause
that — they touch one field of one entry — but a rebuild writes the whole entry list back, and
would drop an entry the mirror never saw.

So the rebuild path reads the table back first and re-applies the batch on top of what it finds.
That is the O(table) read this mirror exists to avoid, and it is close to free next to the rebuild
it precedes — while the hot path, the targeted writes, never pays it. It also re-syncs the mirror,
so a foreign write costs at most the writes dropped between one rebuild and the next rather than
poisoning the mirror for the life of the place.

This package is still meant to be the only writer of `GeneratedJSONTable_*`, which the design
already requires elsewhere. The reconciliation is what keeps a violation recoverable rather than
fatal. Pinned by "preserves an entry written directly to the table after the mirror was built".

## Readiness is per key, not per batch

The obvious barrier — "wait until the pending writes have flushed" — is wrong, and was the original
bug:

- `PromiseEntriesWritten` answers for the batch pending *when it was called*. Writes queued while
  that flush resolves land in the **next** batch, so the promise can resolve before the data you
  are waiting for exists.
- A caller who asks while nothing is pending gets `Promise.resolved()` — no barrier at all.
- It was also captured once, when the observable was built, so a UI constructed after boot was
  never gated.

So readiness is tracked **per translation key**:

| API | Answers |
|---|---|
| `TranslatorService:IsTranslationReady(key)` | is nothing queued for this key |
| `TranslatorService:ObserveIsTranslationReady(key)` | `false`/`true` as that key's writes land |
| `JSONTranslator:_observeTranslationReady(key)` | the locale the key is readable for, or nil |

None of this is something a consumer should reach for. The `JSONTranslator` one is private; the two
on the service are public only because `JSONTranslator` is a separate class that consumes them, and
their docstrings say as much. Every read path (`ObserveFormatByKey`, `PromiseFormatByKey`,
`FormatByKey`, `ObserveTranslation`) already handles readiness on the caller's behalf.

Key invariants:

- A key **nothing ever registered is ready.** There is nothing to wait for, so an unknown key falls
  through to the fallback instead of hanging forever.
- Not-ready is announced only after the value is stored *and* the flush is scheduled, so a handler
  reacting to it sees state that agrees with it.
- The flush fires ready for every key in the batch — including ones `_applyPendingEntries` skipped
  as already-matching, since their data is in the table either way and a key that never went ready
  would strand its readers.
- A key a handler re-queued *during* the fan-out is skipped, because it is pending again.

### Nothing yields

Readiness is driven by the queue and the flush directly. There are no promises and no waits in the
path — which is the point: a translation read must never block a frame.

## Re-entrancy is the hard part

The flush fans out into consumer code while the service is mid-mutation. A handler can legally
register keys, read translations, subscribe, unsubscribe, swap locale, or tear down UI. Rules that
came out of that, each with a regression test:

- **Capture the flush promise before the fan-out.** A handler that registers a key schedules the
  next flush, which installs its own promise; reading the field afterwards resolves the wrong one
  and strands the awaiters of this one.
- **Fan out over a copy, and check a per-observer `Disconnected` flag.** A handler that tears down
  sibling UI unsubscribes other observers of the same key mid-fan-out. (This is also why the
  fan-out does not use `Signal` — `Signal.Fire` caches the next node before invoking a handler, so
  a disconnect during a handler can truncate the chain and silently skip every later observer.)
- **Spawn each callback.** A raising handler must not abort the fan-out and strand the rest.
- **A write after `Destroy` must not re-arm the deferred flush**, or the callback outlives the
  service and writes the stale queue into the shared table a frame after teardown. This matters
  doubly here: the repo runs every package's specs in one shared place, so a leaked defer fails an
  unrelated later package.

## The fallback chain, and why order matters

`JSONTranslator._doTranslation` tries, in order: the cloud translator, the local table translator
for the target locale, then the source translator.

The trap is that a `Translator` **answers in the language it was built for and succeeds**. The
cloud translator is bound to the player's Roblox locale, which a forced locale (a language
selector) does not move — so asked for a key it knows, it returns player-locale text and the chain
stops there, serving the wrong language after a swap.

So a translator is consulted only when `ResolveLocaleUtils.isCompatibleLocale` accepts it for the
locale being translated for. The source translator is exempt: answering in another language is its
whole job.

The local translator is resolved per target locale (`_getLocalTranslator`) rather than read from a
ValueObject that a locale subscription updates. Signal handlers fire **newest-connected first**, so
such a subscription can still hold the previous locale's translator while a reader is translating
for the new one — which rendered the source language permanently when swapping back to an
already-loaded locale.

## Sharp edge: the source locale is a constant

`ToTranslationKey` registers its source under `"en"` — not under the table's `SourceLocaleId`, and
not under the locale the `JSONTranslator` was constructed for. Synchronous reads survive that by
coincidence. `FormatByKey` lands its key through `FlushEntryForKey`, which flushes only the locales
a read can consult (the current locale, the table's `SourceLocaleId`, and both language subtags),
and a fresh `LocalizationTable`'s `SourceLocaleId` is `en-us`, whose subtag is `en`.

Reuse a `GeneratedJSONTable_Client` shipped in a place file with a different source locale and the
`"en"` value falls in none of those buckets: it stays queued past the read, `FormatByKey` misses,
and since that path is one-shot the key renders for the life of whatever drew it. Taking the source
locale from the translator would remove the coincidence. Not fixed today.

## Locale compatibility vs closest key

Two different questions, deliberately two functions:

- `isCompatibleLocale(a, b)` — can one be *read in place of* the other. Same language **and same
  script**. `es-mx` reads `es-es`; `zh-tw` never reads `zh-cn`. Bare `zh` counts as Simplified, so
  it substitutes with `zh-cn` and not with `zh-tw`.
- `resolveClosestKey(locale, available)` — pick the best key from a table the caller owns. It may
  route `zh-tw` to a Simplified key when that is all that exists. Fine for number formatting
  (grouping is the same), wrong for text.

Do not collapse them.

## Emission rules for `ObserveFormatByKey`

- **Emits immediately on subscribe**, best-effort, rather than withholding until the batch lands. A
  subscriber must never be left blank for a frame.
- **Thereafter emits only on ready.** A locale swap must not flicker a good translation back to a
  source-language fallback while the new locale's data is queued.
- The local translator is deliberately **not** a re-emission source, though `_doTranslation` reads
  it: it swaps at the *start* of a locale change, before that locale's data has landed.

### Rejected: reading the pending queue instead

There is a tempting simplification here, and it was considered and turned down.

During the window between a locale swap and that frame's flush, the new locale's text is already
queued in `_pendingEntries` — we have it, the engine just cannot see it yet. So `_doTranslation`
could grow a rung between the local translator and the source translator that reads the queued
value directly. There would then be no wrong state to suppress, which means the latch, the
first-emission exception, and `Rx.distinct` all delete themselves, and first paint would show real
text instead of the translation key.

The blocker is formatting. A queued value is the raw source string (`"Ciao {name}"`); turning it
into `"Ciao James"` is `Translator:FormatByKey`'s job, and Roblox's formatting is documented but
not simple — it is more than `{param}` substitution. Doing it ourselves for one frame risks output
that differs from the engine's in ways that are silent, locale-specific, and would only show up for
players in the affected languages.

A frame of stale-but-correct text beats a frame of subtly wrong text. The latch stays.

If this is revisited, the deciding question is exactly what `FormatByKey` does beyond parameter
substitution — verify that first (see [engine-behavior.md](engine-behavior.md) for how), because
everything else about the change is mechanical.

## Warnings

`_doTranslation` warns only when no translator resolved the key, and only when the key is ready.
Warning per miss floods the console with one line per key per locale swap — the cloud translator
does not know keys registered at runtime, and a queued key is not readable yet by design. Both are
routine, neither is a problem.

## Testing notes

- Specs use the `setup()` / `controller:destroy()` pattern; `destroy` is the last line of each
  test. The shared place makes leaks somebody else's failure.
- Readiness bugs are ordering bugs, so tests that depend on hash iteration order are worthless.
  Where order matters, drive enough keys that whichever one fires first triggers the case (see
  "never reports a key ready while it is pending again").
- Error isolation in the fan-out is **not** testable here: a raising handler surfaces as an uncaught
  error, which fails the whole CLI run.
- When fixing something, check the new test actually fails against the old code. Several tests in
  this package were written, verified by reverting the fix, and rewritten because they passed
  either way.
