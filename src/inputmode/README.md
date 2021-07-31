## InputMode
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

Trace input mode state and trigger changes correctly. This is a more customizable version of UserInputService:GetLastInputType() or LastInputTypeChanged.

## Installation
```
npm install @quenty/inputmode --save
```

## Usage
Usage is designed to be simple.

## INPUT_MODES API

The following InputModes are defined already, and can be used.

```lua
INPUT_MODES.Keypad
INPUT_MODES.Keyboard
INPUT_MODES.ArrowKeys
INPUT_MODES.WASD
INPUT_MODES.Mouse
INPUT_MODES.KeyboardAndMouse
INPUT_MODES.Touch
INPUT_MODES.DPad
INPUT_MODES.Thumbsticks
```
### InputModeSelector

The inputModeSelector has the following API. This is the primary way to interact with this package.

### `function InputModeSelector.new(inputModes)`
A table of input modes to select from

### `function InputModeSelector:GetActiveMode()`
Gets the current active mode object (An InputMode object)

### `function InputModeSelector:Bind(updateBindFunction)`
Binds a function to the active mode.

```lua
local inputModeSelector = InputModeSelector.new({
  INPUT_MODES.Mouse;
  INPUT_MODES.Touch;
})

inputModeSelector:Bind(function(inputMode)
  if inputMode == INPUT_MODES.Mouse then
    print("Show mouse input hints")
  elseif inputMode == INPUT_MODES.Touch then
    print("Show touch input hints")
  else
     -- Unknown input mode
     warn("Unknown input mode") -- should not occur
  end
end)
```

### `function InputModeSelector:Destroy()`


## InputMode API
### `InputMode.new(name, typesAndInputModes)`

### `InputMode:GetLastEnabledTime()`

### `InputMode:GetKeys()`

### `InputMode:IsValid(inputType)`

### `InputMode:Enable()`
Enables the mode

### `InputMode:Evaluate(inputObject)`
Evaluates the input object, and if it's valid, enables the mode


## Changelog

### 1.0.3
Technically this change is breaking, but no one is depending upon these packages yet

- Moved InputKeyMapUtils and ProximityPropmtInputUtils to inputkeymaputils package
- Fixed dependencies

### 1.0.0
Initial release

### 0.0.0
Initial commit
