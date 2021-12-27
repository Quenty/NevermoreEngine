## Camera
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

CameraStackService provides a camera stack of objects that can report a camera state. This allows a composable camera system for a variety of situations that arise, and lets systems interop with each other

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/CameraStackService">View docs →</a></div>

## Installation
```
npm install @quenty/camera --save
```

## Features

* Minor VR support
* Support for composable camera types
* Support for interpolation between camera nodes
* Support for touch and gamepad support and controls
* Support for camera shake

### Camera State
CameraState is an immutable camera system used for camera interpolation. Designed to make camera effects easy, it trades some efficiency and speed for making a not confusing camera system.

Camera state stores internal state of Coordinate frames as quaternions. This means that the classic lerp equation. Operations have been overridden to make this easier to work with.

Ok. It's not entirely immutable. They are kind of lazy, that is, reading data doesn't affect the state of them. There are no
required update loops or anything for the most part.

### Camera effect API
Current Camera Effects have the following API available. Adding new effects means that these two should follow the same API specifications

#### Add `+` operator
Returns a new Summed camera and adds the two effects together. This is used for combining effects

#### `.CameraState`
Indexing the CameraEffect should return the current camera state. This means that state is easy to index.

In previous versions, the following will also work. However, this is no longer true.

* `.State`
* `.CameraState`
* `.Camera`

This will return a `CameraState`

!!! warning
	Note that eventually we plan to deprecate everything but .CameraState

#### DefaultCamera
This class tracks the current camera ROBLOX uses and lets it maintain how it operates using a `BindToRenderStep` trick.

* Should call `BindToRenderStep` during construction
* Only one should exist at once per client (not enforced in code, however)

#### SummedCamera
This class takes two arguments and returns the summation of the two

* Arguments can be either `CameraState` or a CameraEffect, assuming the effect has a `CameraState` member

#### FadingCamera
This classes allows the effects of a camera to be faded / varied based upon a spring

* Starts at 0 percent effect

## Usage
Here is sample usage of using just a subcomponent. Recommendation is to use full camera stack service.

```lua
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FadeBetweenCamera3 = require(modules.FadeBetweenCamera3)
local CustomCameraEffect = require(modules.CustomCameraEffect)
local CameraState = require(modules.CameraState)

local defaultCamera = require(modules.DefaultCamera).new()
defaultCamera:BindToRenderStep() -- capture roblox camera automatically

local targetCamera = CustomCameraEffect.new(function()
  local target = CameraState.new()
  target.CFrame = CFrame.new(0, 100, 0)
  target.FieldOfView = 70

  return target
end)

local faded = FadeBetweenCamera3.new(defaultCamera, targetCamera)
faded.Speed = 5

RunService:BindToRenderStep("CameraStackUpdateInternal", Enum.RenderPriority.Camera.Value + 75, function()
  faded.CameraState:Set(Workspace.CurrentCamera)
end)

-- Input
local mouse = game.Players.LocalPlayer:GetMouse()
local visible = false
mouse.Button1Down:Connect(function()
  visible = not visible
  if visible then
    faded.Target = 1
  else
    faded.Target = 0
  end
end)

```