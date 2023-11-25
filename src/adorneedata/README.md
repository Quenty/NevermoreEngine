## AdorneeData

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

Bridges attributes and serialization

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/AdorneeData">View docs →</a></div>

## Installation

```
npm install @quenty/adorneedata --save
```

## Requirements
These are the requirements for this attribute data library.

* Not like Tie in that it is focused on serialization/boundary between Roblox and our stuff (tie is interfaces separated by network boundary)
* Easy to transform between data and attributes
* No service bag requirements

### Centralized definition with no server/client information
```lua
return AdorneeData.new({
  CurrencyColor = Color3.new();
  CurrencyNameTranslationKey = "";
  CurrencyFormatTranslationKey = "";
  CurrencyImageId = "";
  CurrencyShowType = CurrencyShowTypes.NONE;
  GivePlayerCurrency = false;
  CurrencySaves = false;
})
```

### Easy to write/author
We should be able to create new data that is validated

```lua
CurrencyDefinitionData:CreateData({
  CurrencyKey = CurrencyDefinitionConstants.DEFAULT_CURRENCY_KEY
  CurrencyColor = Color3.fromRGB(55, 180, 74)
  CurrencyTranslationKey = "currency.default.name"
  CurrencyFormatTranslationKey = "currency.default.format"
  DoesSave = true
  ImageId = "rbxassetid://10049671651"
})
```

We should be able to create partial data

```lua
CurrencyDefinitionData:CreatePartialData({
  CurrencyKey = CurrencyDefinitionConstants.DEFAULT_CURRENCY_KEY
  CurrencyColor = Color3.fromRGB(55, 180, 74)
  CurrencyTranslationKey = "currency.default.name"
  CurrencyFormatTranslationKey = "currency.default.format"
  DoesSave = true
  ImageId = "rbxassetid://10049671651"
})
```
#### Additional authorship requirements

* Should be able to set optional values

### Easy to validate/assert/assign

We should be able to check data types

```lua
function CurrencyService:InitCurrencyDefinition(currencyDefinitionData)
  assert(CurrencyDefinitionData:IsData(currencyDefinitionData), "Bad currencyDefinitionData")

  local currencyDefinition = CurrencyDefinition:Create("Folder")
  CurrencyDefinitionData:SetAttributes(currencyDefinition, currencyDefinitionData)

  return currencyDefinition
end
```

### Replacement files

Should replace following files:

* CurrencyDefinitionDataUtils - Files with `t` interface asserting type
* CurrencyDefinitionConstants - Files with constant attribute names
* CurrencyDefinitionUtils - File that sets certain properties or attributes and do validation

### Easy to serialize

Should be able to flash to constant 

