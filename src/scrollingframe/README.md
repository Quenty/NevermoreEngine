## ScrollingFrame
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

Creates an inertia based scrolling frame that is animated and has inertia frames Alternative to a Roblox ScrollingFrame with inertia scrolling and complete control over behavior and style.

Somewhat less recommended these days because Roblox has added inertia scrolling to the mobile experience.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/ScrollingFrame">View docs →</a></div>

## Installation
```
npm install @quenty/scrollingframe --save
```

## Usage
Usage is designed to be simple.

### `ScrollingFrame.new(gui)`
Creates a new ScrollingFrame which can be used. Prefer Container.Active = true so scroll wheel works.

### `ScrollingFrame:SetScrollType(scrollType)`
Sets the scroll type for the frame

### `ScrollingFrame:AddScrollbar(scrollbar)`

### `ScrollingFrame:RemoveScrollbar(scrollbar)`

### `ScrollingFrame:ScrollTo(position, doNotAnimate)`
Scrolls to the position in pixels offset

### `ScrollingFrame:ScrollToTop(doNotAnimate)`
Scrolls to the top

### `ScrollingFrame:ScrollToBottom(doNotAnimate)`
Scrolls to the bottom

### `ScrollingFrame:GetModel()`

### `ScrollingFrame:StopDrag()`

### `ScrollingFrame:BindInput(gui, options)`
Binds input to a specific GUI

### `ScrollingFrame:StartScrolling(inputBeganObject, options)`

### `ScrollingFrame:StartScrollbarScrolling(scrollbarContainer, inputBeganObject)`

### `ScrollingFrame:Destroy()`

