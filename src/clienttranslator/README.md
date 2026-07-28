## ClientTranslator
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Gets local translator for player

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/JSONTranslator">View docs →</a></div>

## Installation
```
npm install @quenty/clienttranslator --save
```

## Working on this package

Read these before changing the translation stack. They exist because most of this package's
behavior is driven by engine quirks that are not obvious from the code:

- [`docs/design.md`](docs/design.md) — how the stack fits together and why: batched localization
  writes, per-key readiness, the translator fallback chain, re-entrancy rules.
- [`docs/engine-behavior.md`](docs/engine-behavior.md) — verified `LocalizationTable` and
  `Translator` behavior the design rests on, and how to verify more of it.

Consumer-facing behavior is documented in
[`docs/gotchas/localization.md`](../../docs/gotchas/localization.md) at the repo root.

## Usage
Usage is designed to be simple.

## Easy-use scenario

1. Call Translate(data, "blah") on anything
2. Translation is magically replicated to clients and can be saved
3. Only one place needed to save the data

## Adding localization files

Add files to ReplicatedStorage/i18n. Files will be in string values, and be valid JSON. This allows lookup like this:

```json
{
  "key": {
    "secondary": {
      "node": "My translated value"
    }
  }
}
```

This will generate an entry like this:

```
"key.secondary.node" --> My translated value
```

Which can be output like this:

```
ClientTranslator:FormatByKey("key.secondary.node") --> My translated value
```

All substitutions and other formats work like Roblox's does.

## Pseudo-localize
There exists a pseudo-locale `qlp-pls` which can be to visualize pseudo-localized text. This can be used to help detect unlocalized text.

## API surface

### `ClientTranslatorFacade:Init()`
Initializes a new instance of the ClientTranslatorFacade.

### `ClientTranslatorFacade:FormatByKey(key, ...)`
Works the same way that Roblox's ClientTranslator:FormatByKey functions. However, functions when not online, and also will utilize a pseudo-locale.



