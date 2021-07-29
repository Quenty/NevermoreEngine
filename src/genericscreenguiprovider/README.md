## GenericScreenGuiProvider
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

Providers screenGuis with a given display order for easy use

## Installation
```
npm install @quenty/genericscreenguiprovider --save
```

## Usage
Usage is designed to be simple.

```lua
-- ScreenGuiProvider.lua


return GenericScreenGuiProvider.new({
  CLOCK = 5; -- Register layers here
  BLAH = 8;
  CHAT = 10;
})
```

In a script that needs a new screen gui, do this:

```lua
-- Load your games provider (see above for the registration)
local screenGuiProvider = require("ScreenGuiProvider")

-- Yay, you now have a new screen gui
local screenGui = screenGuiProvider:Get("CLOCK")
gui.Parent = screenGui
```

## API

### `GenericScreenGuiProvider.new(orders)`

### `GenericScreenGuiProvider:Get(orderName)`
Returns a new ScreenGui at DisplayOrder specified

### `GenericScreenGuiProvider:GetDisplayOrder(orderName)`

### `GenericScreenGuiProvider:SetupMockParent(target)`


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit