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
