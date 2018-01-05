--- Holds input states for Keyboard, Mouse, et cetera. Mostly useful for providing UI input hints to the user by
-- identifying the most recent input state provided.
-- @classmod InputModes

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local InputMode = require("InputMode")
local InputModeSelector = require("InputModeSelector")
local InputModeProcessor = require("InputModeProcessor")
local Maid = require("Maid")

--[[

API:
	InputModes.Keyboard
		Returns an input state for keyboard
	InputModes.Mouse
		Returns an input state for Mouse
	InputModes.Touch
		Returns an input state for Touch
	InputModes.Gamepad
		Returns an input state for Gamepad

	InputModes:BindToSelector(function updateFunction)
		Binds a function to a selector, where the updateFunction is called
		immediately with the current best state between Gamepad, Mouse, and
		Touch. Returns the InputModeSelector to

		void updateFunction(NewState, OldState)
			Called immediately after binding, and then after every change.

		Returns the selector which should be cleaned up with a call of :Destroy()
]]

local InputModes = setmetatable({}, {
	__index = function(self, key)
		error(("'%s' is not a valid InputMode"):format(tostring(key)))
	end;
})

---
-- @field
InputModes.THUMBSTICK_DEADZONE = 0.14

---
-- @param updateFunction Function(NewMode, Maid)
function InputModes:BindToSelector(updateFunction)
	local new = InputModeSelector.new({
		InputModes.Gamepads,
		InputModes.Mouse,
		InputModes.Touch
	}, updateFunction)

	return new
end


do
	local KEYBOARD = "KeypadZero,KeypadOne,KeypadTwo,KeypadThree,KeypadFour,KeypadFive,KeypadSix,KeypadSeven,KeypadEight,"
		.. "KeypadNine,KeypadPeriod,KeypadDivide,KeypadMultiply,KeypadMinus,KeypadPlus,KeypadEnter,KeypadEquals"
	local ALPHABET = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
	local ARROW_KEYS = "Left,Right,Up,Down"

	--- Keyboard InputMode
	-- @field
	InputModes.Keyboard = InputMode.new("Keyboard")
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
		InputModes.Keyboard:Enable()
	end
end

do
	--- Mouse InputMode
	-- @field
	InputModes.Mouse = InputMode.new("Mouse"):AddKeys("MouseButton1,MouseButton2,MouseButton3,MouseWheel,MouseMovement",
		Enum.UserInputType)

	if UserInputService.MouseEnabled then
		InputModes.Mouse:Enable()
	end
end

do
	--- Touch InputMode
	-- @field
	InputModes.Touch = InputMode.new("Touch"):AddKeys("Touch", Enum.UserInputType)

	if UserInputService.TouchEnabled then
		InputModes.Touch:Enable()
	end
end

do
	local GAMEPAD_THUMBSTICKS = "Thumbstick1,Thumbstick2"
	local GAMEPAD_TRIGGERS = "ButtonR2,ButtonL2,ButtonR1,ButtonL1"
	local GAMEPAD_BUTTONS = "ButtonA,ButtonB,ButtonX,ButtonY,ButtonR3,ButtonL3,ButtonStart,ButtonSelect,DPadLeft,"
		.. "DPadRight,DPadUp,DPadDown"

	--- Gamepad InputMode
	-- @field
	InputModes.Gamepads = InputMode.new("Gamepad")
		:AddKeys(GAMEPAD_THUMBSTICKS, Enum.KeyCode)
		:AddKeys(GAMEPAD_BUTTONS, Enum.KeyCode)
		:AddKeys(GAMEPAD_TRIGGERS, Enum.KeyCode)
		:AddKeys("Gamepad1,Gamepad2,Gamepad3,Gamepad4,Gamepad5,Gamepad6,Gamepad7,Gamepad8", Enum.UserInputType)

	if UserInputService.GamepadEnabled then
		InputModes.Gamepads:Enable()
	end
	if GuiService:IsTenFootInterface() then
		InputModes.Gamepads:Enable()
	end
end

--- Construct Processor
-- @local
local function bindProcessor()
	local inputProcessor = InputModeProcessor.new()
		:AddState(InputModes.Keyboard)
		:AddState(InputModes.Gamepads)
		:AddState(InputModes.Mouse)
		:AddState(InputModes.Touch)

	local maid = Maid.new()

	UserInputService.InputBegan:Connect(function(inputObject)
		inputProcessor:Evaluate(inputObject)
	end)

	UserInputService.GamepadConnected:Connect(function(gamepad)
		InputModes.Gamepads:Enable()

		-- Bind thumbsticks
		maid.InputChanged = UserInputService.InputChanged:Connect(function(inputObject)
			if inputObject.KeyCode.Name:find("Thumbstick") then
				if inputObject.Position.magnitude > InputModes.THUMBSTICK_DEADZONE then
					inputProcessor:Evaluate(inputObject)
				end
			end
		end)
	end)

	UserInputService.GamepadDisconnected:Connect(function(gamepad)
		-- TODO: Stop assuming state is mouse/keyboard
		InputModes.Mouse:Enable()
		InputModes.Keyboard:Enable()

		maid.InputChanged = nil
	end)
end

bindProcessor()

return InputModes