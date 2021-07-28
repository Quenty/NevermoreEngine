## ClientTranslator
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/lint/badge.svg" alt="Actions Status" />
  </a>
</div>

Gets local translator for player

## Installation
```
npm install @quenty/clienttranslator --save
```

## Usage
Usage is designed to be simple.

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




## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit