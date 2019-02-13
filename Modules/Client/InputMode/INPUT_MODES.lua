--- Holds input states for Keyboard, Mouse, et cetera. Mostly useful for providing UI input hints to the user by
-- identifying the most recent input state provided.
-- @module INPUT_MODES

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local InputMode = require("InputMode")
local InputModeProcessor = require("InputModeProcessor")
local Maid = require("Maid")

--[[

API:
	INPUT_MODES.Keyboard
		Returns an input state for keyboard
	INPUT_MODES.Mouse
		Returns an input state for Mouse
	INPUT_MODES.Touch
		Returns an input state for Touch
	INPUT_MODES.Gamepad
		Returns an input state for Gamepad
	INPUT_MODES.KeyboardAndMouse
]]

local INPUT_MODES = setmetatable({}, {
	__index = function(self, key)
		error(("'%s' is not a valid InputMode"):format(tostring(key)))
	end;
})

---
-- @field
INPUT_MODES.THUMBSTICK_DEADZONE = 0.14

do
	local KEYBOARD = "KeypadZero,KeypadOne,KeypadTwo,KeypadThree,KeypadFour,KeypadFive,KeypadSix,KeypadSeven,KeypadEight,"
		.. "KeypadNine,KeypadPeriod,KeypadDivide,KeypadMultiply,KeypadMinus,KeypadPlus,KeypadEnter,KeypadEquals"
	local ALPHABET = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
	local ARROW_KEYS = "Left,Right,Up,Down"

	--- Keyboard InputMode
	-- @field
	INPUT_MODES.Keyboard = InputMode.new("Keyboard")
		:AddKeys("Keyboard", Enum.UserInputType) -- Incase we miss anything
		:AddKeys("Backspace,Tab,Clear,Return,Pause,Escape,Space,QuotedDouble,Hash,Dollar,Percent,Ampersand,Quote,"
			.. "LeftParenthesis,RightParenthesis,Asterisk,Plus,Comma,Minus,Period,Slash,Zero,One,Two,Three,Four,Five,Six,Seven,"
			.. "Eight,Nine,Colon,Semicolon,LessThan,Equals,GreaterThan,Question,At,LeftBracket,BackSlash,RightBracket,Caret,"
			.. "Underscore,Backquote", Enum.KeyCode)
		:AddKeys(ALPHABET, Enum.KeyCode)
		:AddKeys("LeftCurly,Pipe,RightCurly,Tilde,Delete,Insert,Home,End,PageUp,PageDown,F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,"
			.. "F12,F13,F14", Enum.KeyCode)
		:AddKeys("NumLock,CapsLock,ScrollLock,RightShift,LeftShift,RightControl,LeftControl,RightAlt,LeftAlt,RightMeta,"
			.. "LeftMeta,LeftSuper,RightSuper,Mode,Compose,Help,Print,SysReq,Break", Enum.KeyCode)
		:AddKeys(KEYBOARD, Enum.KeyCode)
		:AddKeys(ARROW_KEYS)

	if UserInputService.KeyboardEnabled then
		INPUT_MODES.Keyboard:Enable()
	end
end

do
	--- Mouse InputMode
	-- @field
	INPUT_MODES.Mouse = InputMode.new("Mouse"):AddKeys("MouseButton1,MouseButton2,MouseButton3,MouseWheel,MouseMovement",
		Enum.UserInputType)

	if UserInputService.MouseEnabled then
		INPUT_MODES.Mouse:Enable()
	end
end

do
	--- KeyboardAndMouse InputMode
	-- @field
	INPUT_MODES.KeyboardAndMouse = InputMode.new("KeyboardAndMouse")
		:AddInputMode(INPUT_MODES.Mouse)
		:AddInputMode(INPUT_MODES.Keyboard)

	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		INPUT_MODES.KeyboardAndMouse:Enable()
	end
end

do
	--- Touch InputMode
	-- @field
	INPUT_MODES.Touch = InputMode.new("Touch"):AddKeys("Touch", Enum.UserInputType)

	if UserInputService.TouchEnabled then
		INPUT_MODES.Touch:Enable()
	end
end

do
	local GAMEPAD_THUMBSTICKS = "Thumbstick1,Thumbstick2"
	local GAMEPAD_TRIGGERS = "ButtonR2,ButtonL2,ButtonR1,ButtonL1"
	local GAMEPAD_BUTTONS = "ButtonA,ButtonB,ButtonX,ButtonY,ButtonR3,ButtonL3,ButtonStart,ButtonSelect,DPadLeft,"
		.. "DPadRight,DPadUp,DPadDown"

	--- Gamepad InputMode
	-- @field
	INPUT_MODES.Gamepads = InputMode.new("Gamepad")
		:AddKeys(GAMEPAD_THUMBSTICKS, Enum.KeyCode)
		:AddKeys(GAMEPAD_BUTTONS, Enum.KeyCode)
		:AddKeys(GAMEPAD_TRIGGERS, Enum.KeyCode)
		:AddKeys("Gamepad1,Gamepad2,Gamepad3,Gamepad4,Gamepad5,Gamepad6,Gamepad7,Gamepad8", Enum.UserInputType)

	if UserInputService.GamepadEnabled then
		INPUT_MODES.Gamepads:Enable()
	end
	if #UserInputService:GetConnectedGamepads() > 0 then
		INPUT_MODES.Gamepads:Enable()
	end
	if GuiService:IsTenFootInterface() then
		INPUT_MODES.Gamepads:Enable()
	end
end

--- Construct Processor
-- @local
local function bindProcessor()
	local inputProcessor = InputModeProcessor.new()
		:AddState(INPUT_MODES.Keyboard)
		:AddState(INPUT_MODES.Gamepads)
		:AddState(INPUT_MODES.Mouse)
		:AddState(INPUT_MODES.Touch)
		:AddState(INPUT_MODES.KeyboardAndMouse)

	UserInputService.InputBegan:Connect(function(inputObject)
		inputProcessor:Evaluate(inputObject)
	end)

	local maid = Maid.new()

	UserInputService.GamepadConnected:Connect(function(gamepad)
		INPUT_MODES.Gamepads:Enable()

		-- Bind thumbsticks
		maid._inputChanged = UserInputService.InputChanged:Connect(function(inputObject)
			if inputObject.KeyCode.Name:find("Thumbstick") then
				if inputObject.Position.Magnitude > INPUT_MODES.THUMBSTICK_DEADZONE then
					inputProcessor:Evaluate(inputObject)
				end
			end
		end)
	end)

	UserInputService.GamepadDisconnected:Connect(function(gamepad)
		-- TODO: Stop assuming state is mouse/keyboard
		INPUT_MODES.Mouse:Enable()
		INPUT_MODES.Keyboard:Enable()

		maid._inputChanged = nil
	end)
end

bindProcessor()

return INPUT_MODES