---
title: Localization
sidebar_position: 3
---

# Localization gotchas

Surprises specific to `LocalizationTable` and the translation stack.

## A LocalizationTable keys its entries by translation key alone

At runtime a `LocalizationTable` treats the **translation key as the unique identifier** for an
entry. Source and context are stored as metadata but do **not** widen the identity:

- `SetEntryValue(key, sourceA, contextA, ...)` followed by
  `SetEntryValue(key, sourceB, contextB, ...)` leaves a **single** entry — the second call
  overwrites the source/context in place (last write wins).
- `SetEntries` **rejects** any array containing two entries that share a key, even when their
  source and context differ. It throws:

  ```
  Entry at index N has the same (key) or (key,source,context) tuple as another entry.
  ```

  Despite the "(key,source,context)" wording, two entries with the same key and *distinct*
  non-empty contexts still collide. When the context is empty the check narrows further to the
  key only (ignoring source). The duplicate check also trims surrounding whitespace on source and
  context, so `"ctx"` and `"ctx "` are treated as the same.

`GetEntries` returns whatever was stored verbatim (no trimming, no normalization), so a
round-trip through `GetEntries` → mutate → `SetEntries` will blow up if the array ever holds two
entries the engine considers the same key.

### Why this matters for batched writes

`TranslatorService` batches localization writes and applies them with one `SetEntries` call per
flush. It therefore holds **at most one pending delta per translation key**; a later write for the
same key with a different source/context overwrites the pending entry rather than queueing a second
one. Queuing per `(key, source, context)` instead — the original design — fed `SetEntries` a
duplicate key whenever a game registered the same key twice (e.g. `collectable.toolUnlocked`
written both as a collectable name and again as a generated dialog line), crashing the flush.

The behaviors above were established empirically against Open Cloud; see
`TranslatorService.spec.lua` ("TranslatorService entry merging") for the regression tests.

## A translator answers in its own locale, and will happily answer in the wrong language

`Translator:FormatByKey` is bound to the locale the translator was built for. Two consequences:

- A key with no value for that locale **raises** (`Key <key> not found for locale <locale>`)
  rather than returning nil or falling back to the source locale. Every read has to be wrapped.
- The cloud translator from `LocalizationService:GetTranslatorForPlayerAsync` is bound to the
  **player's Roblox locale**, which an in-game language selector does not move. Asked for a key it
  knows, it returns the player-locale text and **succeeds** — so a fallback chain that tries it
  first silently serves the wrong language after a locale swap.

`JSONTranslator._doTranslation` therefore only consults a translator that
`ResolveLocaleUtils.isCompatibleLocale` accepts for the locale being translated for, before falling
back to the source translator (whose job is to answer in another language).

Compatible means same language **and same script**, which is not the same as sharing a language
subtag:

- Regional variants substitute: `es-mx` reads `es-es`, `en-gb` reads `en-us`, `pt-br` reads
  `pt-pt`. Losing this would break the regional fallback games rely on.
- Scripts do not: `zh-tw` never reads `zh-cn`. Chinese carries its script in the region
  (`zh-tw`/`zh-hk`/`zh-mo` are Traditional) as often as in a script subtag (`zh-Hant`), so both
  spellings have to be understood. The same holds for any language with differing script subtags,
  such as `sr-Latn` and `sr-Cyrl`.
- A locale that names no script reads as either, so `sr` and `sr-Cyrl` substitute.

Note this is a different question from `ResolveLocaleUtils.resolveClosestKey`, which picks the
best available key from a table the caller owns and may deliberately route `zh-tw` to a
Simplified key when that is all that exists (fine for number formatting, wrong for text).

## Localization writes are batched, so a key is not readable the instant it is registered

`TranslatorService` defers writes to the end of the frame, because a game streaming in registers
thousands of entries in a single frame and every raw table write invalidates every `AutoLocalize`
entry in the engine. A read taken the moment a key is registered therefore misses.

**You do not have to do anything about this.** Every way of reading a translation —
`ObserveFormatByKey`, `PromiseFormatByKey`, `FormatByKey`, `ObserveTranslation` — already waits for
the key it is reading and re-reads when a locale swap brings new data in. The rest of this section
is about how, and matters only if you are working on the translation stack itself.

Readiness is tracked **per key**, by `TranslatorService:ObserveTranslationReady` /
`IsTranslationReady`, and consumed by `JSONTranslator`. Do **not** reach for
`PromiseEntriesWritten` instead: it resolves for the batch pending *when it was called*, which is
not the batch containing the data you are about to read — writes queued during that flush's own
resolution land in the next batch, and a caller who asks while nothing is pending gets an
already-resolved promise.

A key nothing ever registered reads as ready, so an unknown key falls through to the fallback
instead of hanging. Synchronous reads (`JSONTranslator:FormatByKey`) use `FlushEntryForKey` to land
only the locales that read can consult, leaving the rest of the batch queued.

`ObserveFormatByKey` emits a best-effort value immediately rather than withholding its first
emission, so a UI bound to it is never blank for a frame; it re-emits the correct text once the key
lands. It will not flicker a good translation back to a fallback during a locale swap.

See `JSONTranslator.TranslationReady.spec.lua` for the readiness contract and
`TranslatorService.spec.lua` ("TranslatorService write cost while streaming in") for the batching
cost this is protecting.
