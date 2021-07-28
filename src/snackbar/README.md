## Snackbar
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

Snackbars provide lightweight feedback on an operation at the base of the screen. They automatically disappear after a timeout or user interaction. There can only be one on the screen at a time.

## Installation
```
npm install @quenty/snackbar --save
```

## Usage
Using the snackbar should be done via the SnackbarManager, which ensures only one snackbar can be visible at a time.

```lua
-- Client script

require("SnackbarManager"):Init(screenGui)

-- Sometime later on the client

require("SnackbarManager"):MakeSnackbar("Hello world!")
```

## SnackbarManager API
Usage is designed to be simple.

### `SnackbarManager:Init(screenGui)`

### `SnackbarManager:WithScreenGui(screenGui)`
Sets the screenGui to use

### `SnackbarManager:MakeSnackbar(text, options)`

## DraggableSnackbar API
Usage is designed to be simple.

### `DraggableSnackbar.new(Parent, Text, GCOnDismissal, Options)`
Note that this will not show until :Show() is called

### `DraggableSnackbar:Show()`

### `DraggableSnackbar:StartTrack(X, Y)`

### `DraggableSnackbar:Track()`

### `DraggableSnackbar:GetOffsetXY()`

### `DraggableSnackbar:EndTrack()`

### `DraggableSnackbar:Dismiss()`

### `DraggableSnackbar:IsVisible()`

### `DraggableSnackbar:Destroy()`

## Snackbar API

### `Snackbar.new(Parent, Text, options)`

### `Snackbar:Dismiss()`

### `Snackbar:SetBackgroundTransparency(Transparency)`

### `Snackbar:FadeOutTransparency(PercentFaded)`

### `Snackbar:FadeInTransparency(PercentFaded)`
Will animate unless given PercentFaded

### `Snackbar:FadeHandler(NewPosition, DoNotAnimate, IsFadingOut)`

### `Snackbar:FadeOutUp(DoNotAnimate)`

### `Snackbar:FadeOutDown(DoNotAnimate)`

### `Snackbar:FadeOutRight(DoNotAnimate)`

### `Snackbar:FadeOutLeft(DoNotAnimate)`

### `Snackbar:FadeIn(DoNotAnimate)`


## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit