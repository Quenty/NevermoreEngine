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
  |     |
  |     +-- TemplateProvider (instance loader only, one per translator)
  |           fetches a locale file on demand instead of replicating all of them
  |
  +-- TranslatorService (shared, one per realm)
        owns the LocalizationTable, batches writes, tracks per-key readiness,
        resolves the current locale and the Roblox translators
```

Loaders only ever *queue*. Everything that touches the `LocalizationTable` goes through
`TranslatorService`.

Every box is a service. A `JSONTranslator` registers its loader on the bag during its own `Init`,
and an `InstanceLocaleLoader` registers its `TemplateProvider` during *its* `Init`, so the standard
initialization chain builds the whole stack and tears it down in reverse. Nothing in it owns
anything below it.

## Locale files are fetched, not replicated

An instance-decoded translator is a folder of per-locale JSON under `ReplicatedStorage`. Left
alone, all of it replicates to every client at join — a game with a dozen languages ships twelve to
a player who reads one. So `InstanceLocaleLoader` reaches its files through a `TemplateProvider`
named for the translator, which on a live server parks them under a `PreventReplication` camera and
replicates name-only tombstones. The client learns which locales exist without their contents, and
fetches the one it needs.

**Why the provider rather than a remote returning the JSON.** A locale file may be a `ModuleScript`
(`decodeLocaleFromInstance` requires it), and a server-only instance returned from a remote arrives
as `nil` — the client has no reference to something it never received. `TemplateProvider`'s
parent-into-`PlayerGui`-then-return is not incidental machinery for meshes; it is the only way to
hand a client an instance it does not have. For the `StringValue` case a remote would move the same
bytes, and would mean rebuilding the request dedup, the pending-promise map, and the locale
manifest the provider already has.

Four consequences worth knowing before changing any of this:

**Loading is asynchronous, but only on a live client.** `TemplateReplicationModesUtils.inferReplicationMode`
returns `SHARED` when `RunService:IsRunning()` is false, and the server path registers its templates
during `Init`, so `PromiseTemplate` resolves synchronously in Studio edit, on the server, and under
the test runner. Loading there behaves exactly as it did before any of this — which is also why
the specs do not exercise the replicated path at all.

**Decode order has to be forced.** The source locale establishes the `Source`/`Context` that every
other locale's values merge onto, and once files are fetched the order they arrive in has nothing
to do with the order they were asked for. Non-source files therefore chain behind
`PromiseSourceLocale` before decoding; the fetches still overlap, only the decode is serialized.

**"No file for this locale" and "not yet" are the same observation.** A client learns the locale set
as tombstones replicate, so concluding absence from an empty set would silently skip a file that
was merely late. `_promiseFileName` waits instead, and a file appearing later re-triggers loading
for any language already requested. A locale that genuinely has no file warns after five seconds
rather than hanging quietly.

**`PromiseLoaded` waits for the source locale**, not just the cloud translator. Acquiring the
translator takes 20–30 seconds and dominates a fetch in practice, so this changes nothing
observable — but it makes "awaited `PromiseLoaded`, so `FormatByKey` works" true by construction
instead of true by luck.

## Nobody loads every locale, so the export asks

Both realms are lazy: the client loads the source plus whichever language the player reads, and a
server loads only the source — it registers a translator mostly so the files are hidden and
servable, and decoding a dozen languages into a table nothing there reads is pure cost. Off-client
used to be eager (`LoadAllLocales`), which made `GeneratedJSONTable_Server` the one place the full
set existed.

That was the CSV export's only supply, so removing it needs a replacement rather than nothing:
`TranslatorService.PromiseLoadAllLocales` walks every registered loader, and
`TranslatorCmdrService` exposes it as `prepare-localization-export`. Every `JSONTranslator`
registers its loader on the service during `Init` for this and nothing else — there is no registry
of translators otherwise, and one exists here only because "give me all of it" has no other way to
reach them.

The command yields until the batch has flushed before reporting, because the next thing the
operator does is read the table by hand.

## The server has to register the translator too

A `TemplateProvider` only hides and tombstones on the realm where it is *initialized*. A translator
registered on the client bag alone means no server provider, so nothing is hidden, the whole
language set replicates at join, and the client's provider quietly finds the real files and works.
Everything behaves correctly and the entire saving is gone.

Since nothing looks wrong when this happens, `InstanceLocaleLoader` warns once when it is running
on a live `CLIENT` realm and sees a locale file it never saw a tombstone for. That is always this
misconfiguration.

One file per locale. The provider keys templates by name, so a second file resolving to the same
locale can never be fetched; the loader warns and ignores it rather than losing half a language
silently.

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

The targeted route trusts each call to leave the rest of the entry alone, and it cannot carry source
or context: on an entry that already exists those are arguments `SetEntryValue` matches on rather
than fields it writes, so the entry keeps the metadata it was created with. A batch that changes any
metadata is therefore rebuilt rather than written — rare next to the value writes this path exists
for, and the alternative is a metadata change that silently does not land while the mirror believes
it did. The same reason keeps `FlushEntryForKey` from moving the mirror's metadata when it lands a
value early. What the engine does and does not guarantee here is written up in
[`engine-behavior.md`](engine-behavior.md), pinned by "LocalizationTable behavior the targeted
writes rest on" and "queues a write that changes only the source or context".

### Registering unchanged text is free

`ToTranslationKey` registers its source text as a side effect of minting the key, so **every** label
built through `ObserveTranslation` re-registers text the table already holds. Queuing those would
schedule a flush, take the key not-ready, and drive a re-translation pass through every reader of
it — per label, per frame, in the source language, where there is nothing to translate at all.

`SetEntryValue`/`SetEntryExample` therefore drop a write the table already agrees with before it
queues. Source and context count as part of the value: a change in either still writes.

#### …but minting does not ask about context

That last sentence had a sharp edge, and it cost a frame spike per line of dialog.

An authored line is normally registered **twice**: once by the loader at boot, from the locale
file, and again by `ToTranslationKey` the first time the line is shown. They agree on the key, the
source, and the text, and they disagree on the context — the loader writes `Generated from <name>
with key <key>`, minting writes `automatic.<key>`. So the currency check above let the write
through, and it was a write that changed *nothing but metadata*, which no targeted call can land
(see "Two write regimes"). Every such line therefore rebuilt the whole table on the frame it first
reached the screen: correct output, one full re-serialization per new line of dialog, and silence
afterwards because the mirror then agreed.

So `ToTranslationKey` asks `TranslatorService:IsEntryRegistered`, which compares key, source and
text and is **blind to context**. Nothing a player or a reader can observe depends on which of the
two descriptions won, and the CSV export is fine with either.

The context still matters where it is load-bearing — it is what keeps `SetEntries` from rejecting
two entries as duplicates — so it is written whenever the entry is created, and a genuine
metadata change still rebuilds. What is gone is the manufactured one. Pinned by "does not
re-register a key a locale file already loaded".

Which of the two descriptions an entry ends up carrying is decided by flush timing, and that is
fine but worth knowing before you go looking for it in a CSV export. A key that is minted after
its loader's batch has landed keeps the loader's context, because the mint is skipped outright. A
key minted in the *same frame* as the load — the ordinary boot, where `Init` queues the source
locale and the UI paints from it before the deferred flush runs — is still pending, so
`IsEntryRegistered` refuses to conclude anything (see `_getCurrentEntry`), the mint proceeds, and
it overwrites the queued entry's context with `automatic.<key>`. That costs no rebuild — the two
writes merge into one pending entry that has yet to be created — and uniqueness survives either
way, since both spellings are derived from the key. So a real table holds a mix of both, split on
when each line first reached the screen.

Minting was also carrying something it had no business carrying: the Studio pseudo-locale value,
written as a side effect of `SetEntryValue` on that second registration. Skipping the second
registration therefore took pseudo-localization with it for keys the loaders own — silently, and
only in Studio, where no cloud test can see it. The parser had been attaching that value to the
entry all along (`LocalizationEntryParserUtils`); `TableLocaleLoader` forwarded it and
`InstanceLocaleLoader` did not. Now both do, on the source-locale pass, which is where it is
derived from anyway. Minting backfilling it was always the accident.

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

"Ready" is per locale, and per locale means per fallback set. A key queued under `en` is not ready
for a player on `en-us`, because that is the value the read would have resolved through
(engine-behavior.md, "A regional translator resolves values stored under the bare language").
Comparing the exact locale alone made the gate a no-op for every regional player: a boot warned
once for each key the first frame it was painted, all of them real keys that read correctly a frame
later.

The fallback set includes the table's source locale, so the gate is now nearly as wide as
`IsTranslationReady` — almost every queued entry carries a source-locale value. The cost is a
genuine "this key has no French" going unwarned while anything is queued under `en` for it, which
is the right trade here: the alternative is the flood above, and a missing translation is visible
in the output either way. Anything that needs the strict answer should ask a translator, not this.

## Testing notes

- Specs use the `setup()` / `controller:destroy()` pattern; `destroy` is the last line of each
  test. The shared place makes leaks somebody else's failure.
- The harnesses `Init()` their service bag but deliberately never `Start()` it. A bag refuses new
  service types once started, and building a translator or a loader registers services (a loader,
  and under it a `TemplateProvider`) — so tests build them in the same window production does,
  during `Init`. Nothing in this stack defines `Start`, so nothing is skipped.
- Locale-file replication is **not** covered. Under the test runner `RunService:IsRunning()` is
  false, so the provider resolves everything locally and synchronously; the tombstone path only
  runs on a live server/client pair. What the specs do cover is the reactive half — a file
  appearing after its locale was requested.
- Readiness bugs are ordering bugs, so tests that depend on hash iteration order are worthless.
  Where order matters, drive enough keys that whichever one fires first triggers the case (see
  "never reports a key ready while it is pending again").
- Error isolation in the fan-out is **not** testable here: a raising handler surfaces as an uncaught
  error, which fails the whole CLI run.
- When fixing something, check the new test actually fails against the old code. Several tests in
  this package were written, verified by reverting the fix, and rewritten because they passed
  either way.
