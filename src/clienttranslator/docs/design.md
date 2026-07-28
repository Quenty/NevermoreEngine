# ClientTranslator design

How the translation stack works internally, and why. This is for people changing this package —
consumers do not need any of it. Consumer-facing behavior lives in
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

## Writes are batched, and that is not negotiable

Every raw write to a `LocalizationTable` invalidates every `AutoLocalize` entry in the engine. A
game streaming in registers thousands of entries in a single frame, so writing per entry is a
frame-killer. `TranslatorService` accumulates deltas and applies them with **one `SetEntries` call
per frame**, via `task.defer`.

`TranslatorService.spec.lua` ("write cost while streaming in") pins this: the write count is `1`
whether ten or five hundred entries register in the frame. If a change makes that number scale with
entry count, the change is wrong, however clean it looks.

The cost of batching is that **a key is not readable the instant it is registered**. Everything
below exists to pay that cost without giving up the batching.

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
| `TranslatorService:ObserveTranslationReady(key)` | `false`/`true` as that key's writes land |
| `JSONTranslator:ObserveTranslationReady(key)` | the locale the key is readable for, or nil |

All three are implementation detail. Every public read path (`ObserveFormatByKey`,
`PromiseFormatByKey`, `FormatByKey`, `ObserveTranslation`) already consumes them, and the docstrings
warn consumers off.

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

## Locale compatibility vs closest key

Two different questions, deliberately two functions:

- `isCompatibleLocale(a, b)` — can one be *read in place of* the other. Same language **and same
  script**. `es-mx` reads `es-es`; `zh-tw` never reads `zh-cn`.
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
