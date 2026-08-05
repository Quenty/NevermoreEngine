# Roblox localization engine behavior

Verified behavior of `LocalizationTable` and `Translator` that this package is built around. All of
it was established empirically against Open Cloud, not read off the documentation — where the two
disagree, this file is what the code assumes.

Consumer-facing consequences live in
[`docs/gotchas/localization.md`](../../../docs/gotchas/localization.md); the design that follows
from these is in [`design.md`](design.md).

## A LocalizationTable keys its entries by translation key alone

Source and context are metadata; they do **not** widen an entry's identity.

- `SetEntryValue(key, sourceA, contextA, ...)` then `SetEntryValue(key, sourceB, contextB, ...)`
  leaves a **single** entry — the second call overwrites source/context in place, **provided it
  also changes the value**. Called with the text the locale already holds it lands nothing at all,
  source and context included: the new metadata is silently discarded. There is therefore no
  targeted call that changes only an entry's metadata, and `TranslatorService` rebuilds the table
  for a batch that changes nothing else. Pinned by `TranslatorService.spec.lua` ("queues a write
  that changes only the source or context").
- `SetEntries` **rejects** an array holding two entries that share a key, even with differing
  source and context:

  ```
  Entry at index N has the same (key) or (key,source,context) tuple as another entry.
  ```

  Despite the "(key,source,context)" wording, same key with *distinct* non-empty contexts still
  collides. With an empty context the check narrows further to the key alone, ignoring source. The
  check also trims surrounding whitespace, so `"ctx"` and `"ctx "` are the same.

`GetEntries` returns what was stored verbatim — no trimming, no normalization — so a
`GetEntries` → mutate → `SetEntries` round trip throws if the array ever holds two entries the
engine considers equal.

**Consequence for this package:** `TranslatorService` holds at most one pending delta per key. The
original design queued per `(key, source, context)` and fed `SetEntries` a duplicate key whenever a
game registered the same key twice (e.g. `collectable.toolUnlocked` written as a collectable name
and again as a generated dialog line), crashing the flush. Pinned by
`TranslatorService.spec.lua` ("entry merging").

## A targeted write leaves the rest of the entry alone

`SetEntryValue` does not disturb the entry's example, and `SetEntryExample` does not disturb its
values. Pinned by `TranslatorService.spec.lua` ("LocalizationTable behavior the targeted writes
rest on"), because `TranslatorService` lands small batches as targeted writes and mirrors the
result rather than reading the table back — a call that clobbered a neighbouring field would put
the mirror permanently out of step with the table, silently.

What is **not** established is whether `SetEntryExample` overwrites source and context in place at
all. It does not need to be: no targeted call lands metadata on its own (see above), so the flush
never asks an example write to carry it; see [`design.md`](design.md) ("Two write regimes").

## Write cost: assumed, not measured

The two write regimes rest on a cost model that was reasoned about rather than profiled:

- every mutating call — `SetEntries` and `SetEntryValue` alike — invalidates the engine's cached
  table contents, so N targeted writes cost N invalidations;
- `SetEntries` additionally re-serializes every entry in the table, so its cost scales with the
  table rather than with the batch.

The symptom that motivated it is real and reproducible — a frame spike each time new text appeared
on screen, on a table holding thousands of entries — but `INVALIDATION_ENTRY_COST` (the ratio
between the two) is a judgment call. If you profile this properly, write the numbers here.

## `Translator:FormatByKey` raises for a missing key

It does not return nil, and it does not fall back to the table's source locale. The error text is:

```
Key <key> not found for locale <locale>
```

Every read has to be wrapped in a `pcall`. This error text is also what a console flood of
"Key X not found for locale Y" actually is — a fallback chain warning on each miss, not the engine
complaining.

## A translator answers in the language it was built for — and succeeds

This is the subtle one. `LocalizationService:GetTranslatorForPlayerAsync` returns a translator
bound to the **player's Roblox locale**. An in-game language selector does not move that. Asked for
a key it knows, it returns player-locale text and **succeeds**, so a fallback chain that consults
it first silently serves the wrong language after a locale swap.

A translator's locale is readable as `translator.LocaleId`.

## Entries written after a translator was obtained are visible to it

A `Translator` is **not** a snapshot. Obtaining one for a locale that has no data yet, then writing
that locale's values, makes the existing translator resolve them — synchronously, in the same
frame, whether the write went through `SetEntryValue` or `SetEntries`, and whether the entries
array passed to `SetEntries` was freshly built or a mutated `GetEntries` result.

This is why `_getLocalTranslator` can cache one translator per locale.

## A fresh LocalizationTable's SourceLocaleId is `en-us`

Not `en`. Relevant because loaders key source-locale data under whatever the folder's file is named
(usually `en`), so the table's source locale and the data's source locale are not the same string.
`FlushEntryForKey` therefore lands the locale, the table's source locale, and the bare language
subtag of each.

## How to check any of this yourself

The fastest loop is a temporary spec in the package plus a deliberately failing assertion, which
prints the values in the diff:

```lua
expect({ before = before, after = after }).toBe(nil)
```

Then `nevermore test --cloud` from the package directory. `--script-text` exists but its output did
not surface through the CLI when this was written; the failing-assertion trick did.
