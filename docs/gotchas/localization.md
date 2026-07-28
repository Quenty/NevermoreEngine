---
title: Localization
sidebar_position: 3
---

# Localization gotchas

What surprises people using the translation stack in a game.

:::note
This page is about using the stack. Why it behaves this way — batched localization writes, per-key
readiness, the translator fallback chain, and the engine behavior all of it is built around — is
documented alongside the package, in
[`src/clienttranslator/docs/`](https://github.com/Quenty/NevermoreEngine/tree/main/src/clienttranslator/docs).
Go there if you are changing the stack, or if you want to know *why* something below behaves the
way it does.
:::

## Which locale file a player actually gets

A player's locale is matched to your locale files by **language and script**, not by exact name:

- **Regional variants substitute.** Ship `es-es.json` and an `es-mx` player reads it. Same for
  `en-gb` reading `en-us`, or `pt-br` reading `pt-pt`.
- **Scripts never substitute.** A `zh-tw` player will **not** read `zh-cn.json`. Traditional and
  Simplified are separate: ship both. Chinese carries its script in the region (`zh-tw`, `zh-hk`,
  `zh-mo` are Traditional) as often as in the name (`zh-hant`), and both spellings work.
- The same applies to any language with distinct scripts, such as `sr-latn` and `sr-cyrl`. Where a
  file names no script at all it reads as either, so `sr.json` serves both — except in Chinese,
  where a bare `zh.json` counts as Simplified.

When nothing matches, the player gets the source locale — usually your `en.json`.

## A key with no translation renders as the key

If no locale file and no uploaded cloud translation resolves a key, the text you get back is the
translation key itself (`quests.groups.theBeginning`), and one warning is logged. That is the
signal that a key is missing everywhere, not just in the current language — a key missing only in
the current language quietly falls back to the source locale instead.

## Text may correct itself a frame after it appears

`ObserveFormatByKey` emits immediately so a label is never blank, then re-emits the real
translation once the key's data is in place. A label can therefore show the raw key for a frame on
first load. It will not flicker backwards: once you have a good translation, a locale swap replaces
it with the new language's text and never with a fallback.

You do not need to wait for anything to make this work. Every read path — `ObserveFormatByKey`,
`PromiseFormatByKey`, `FormatByKey`, `ObserveTranslation` — already handles it.

## One entry per translation key

A `LocalizationTable` treats the translation key as the whole identity of an entry. Registering the
same key twice with a different source or context does not create a second entry — the later write
overwrites the source and context of the first. Plan keys to be unique on their own; do not rely on
context to disambiguate two uses of one key.
