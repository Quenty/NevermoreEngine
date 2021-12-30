## Snackbar
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

Snackbars provide lightweight feedback on an operation at the base of the screen. They automatically disappear after a timeout or user interaction. There can only be one on the screen at a time.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/Snackbar">View docs →</a></div>

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

