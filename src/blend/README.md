## Blend
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Declarative UI system inspired by Fusion

## Installation
```
npm install @quenty/blend --save
```

## Attributes

This system is designed to be very similar to fusion, except that we do not having any global state management, do not rely upon weak references, works with my types, and is built on top of Rx types.

* No global state
* Extensible
* No implicit reliance upon GC

## Usage

See files in src/Client/Test that are stories. Blend returns an observable that will create/return one instance.

Note that subscribe function anchors everything into a maid/cleanup function that can be used to disconnect the whole tree.

```lua
local require = ... -- Nevermore import here
local Blend = require("Blend")
local Maid = require("Maid")

local maid = Maid.new()

local isVisible = Instance.new("BoolValue")
isVisible.Value = false

local percentVisible = Blend.Spring(Blend.Computed(isVisible, function(visible)
  return visible and 1 or 0
end), 35)

local transparency = Blend.Computed(percentVisible, function(percent)
  return 1 - percent
end)

maid:GiveTask((Blend.New "Frame" {
  Size = UDim2.new(0.5, 0, 0.5, 0);
  BackgroundColor3 = Color3.new(0.9, 0.9, 0.9);
  AnchorPoint = Vector2.new(0.5, 0.5);
  Position = UDim2.new(0.5, 0, 0.5, 0);
  BackgroundTransparency = transparency;
  Parent = parent; -- TODO: Assign parent

  [Blend.Children] = {
    Blend.New "UIScale" {
      Scale = Blend.Computed(percentVisible, function(percent)
        return 0.8 + 0.2*percent
      end);
    };
    Blend.New "UICorner" {
      CornerRadius = UDim.new(0.05, 0);
    };
  };
}):Subscribe())
```