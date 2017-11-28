local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local InputMode = LoadCustomLibrary("InputMode")
local InputModeSelector = LoadCustomLibrary("InputModeSelector")
local InputModeProcessor = LoadCustomLibrary("InputModeProcessor")
local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

--[[
class InputModes

Description:
	Holds input states for Keyboard, Mouse, et cetera. Mostly useful for
	providing UI input hints to the user by identifying the most recent input
	state provided. 

API:
	InputModes.Keyboard
		Returns an input state for keyboard
	InputModes.Mouse
		Returns an input state for Mouse
	InputModes.Touch
		Returns an input state for Touch
	InputModes.Gamepad
		Returns an input state for Gamepad

	InputModes:BindToSelector(function UpdateFunction)
		Binds a function to a selector, where the UpdateFunction is called 
		immediately with the current best state between Gamepad, Mouse, and 
		Touch. Returns the InputModeSelector to 

		void UpdateFunction(NewState, OldState)
			Called immediately after binding, and then after every change.

		Returns the selector which should be cleaned up with a call of :Destroy()
]]

local InputModes = setmetatable({}, {
	__index = function(self, Key)
		error(("'%s' is not a valid InputMode"):format(tostring(Key))); 
	end;
})
InputModes.THUMBSTICK_DEADZONE = 0.14

-- @param UpdateFunction Function(NewMode, Maid)
function InputModes:BindToSelector(UpdateFunction)
	local New = InputModeSelector.new({
		InputModes.Gamepads, 
		InputModes.Mouse, 
		InputModes.Touch
	}, UpdateFunction)
	
	return New
end


do -- Keyboard
	local KEYBOARD = "KeypadZero,KeypadOne,KeypadTwo,KeypadThree,KeypadFour,KeypadFive,KeypadSix,KeypadSeven,KeypadEight,KeypadNine,KeypadPeriod,KeypadDivide,KeypadMultiply,KeypadMinus,KeypadPlus,KeypadEnter,KeypadEquals"
	local ALPHABET = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
	local ARROW_KEYS = "Left,Right,Up,Down"

	InputModes.Keyboard = InputMode.new()
		:AddKeys("Keyboard", Enum.UserInputType) -- Incase we miss anything
		:AddKeys("Backspace,Tab,Clear,Return,Pause,Escape,Space,QuotedDouble,Hash,Dollar,Percent,Ampersand,Quote,LeftParenthesis,RightParenthesis,Asterisk,Plus,Comma,Minus,Period,Slash,Zero,One,Two,Three,Four,Five,Six,Seven,Eight,Nine,Colon,Semicolon,LessThan,Equals,GreaterThan,Question,At,LeftBracket,BackSlash,RightBracket,Caret,Underscore,Backquote", Enum.KeyCode)
		:AddKeys(ALPHABET, Enum.KeyCode)
		:AddKeys("LeftCurly,Pipe,RightCurly,Tilde,Delete,Insert,Home,End,PageUp,PageDown,F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12,F13,F14", Enum.KeyCode)
		:AddKeys("NumLock,CapsLock,ScrollLock,RightShift,LeftShift,RightControl,LeftControl,RightAlt,LeftAlt,RightMeta,LeftMeta,LeftSuper,RightSuper,Mode,Compose,Help,Print,SysReq,Break", Enum.KeyCode)
		:AddKeys(KEYBOARD, Enum.KeyCode)
		:AddKeys(ARROW_KEYS)

	if UserInputService.KeyboardEnabled then
		InputModes.Keyboard:Enable()
	end
end

do -- Mouse
	InputModes.Mouse = InputMode.new():AddKeys("MouseButton1,MouseButton2,MouseButton3,MouseWheel,MouseMovement", Enum.UserInputType)

	if UserInputService.MouseEnabled then
		InputModes.Mouse:Enable()
	end
end

do -- Touch
	InputModes.Touch = InputMode.new():AddKeys("Touch", Enum.UserInputType)

	if UserInputService.TouchEnabled then
		InputModes.Touch:Enable()
	end
end

do -- Gamepad
	local GAMEPAD_THUMBSTICKS = "Thumbstick1,Thumbstick2"
	local GAMEPAD_TRIGGERS = "ButtonR2,ButtonL2,ButtonR1,ButtonL1"
	local GAMEPAD_BUTTONS = "ButtonA,ButtonB,ButtonX,ButtonY,ButtonR3,ButtonL3,ButtonStart,ButtonSelect,DPadLeft,DPadRight,DPadUp,DPadDown"

	InputModes.Gamepads = InputMode.new()
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

-- Construct Processor
local InputProcessor = InputModeProcessor.new()
	:AddState(InputModes.Keyboard)
	:AddState(InputModes.Gamepads)
	:AddState(InputModes.Mouse)
	:AddState(InputModes.Touch)

do
	local Maid = MakeMaid()

	Maid:GiveTask(UserInputService.InputBegan:Connect(function(InputObject)
		InputProcessor:Evaluate(InputObject)
	end))

	Maid:GiveTask(UserInputService.GamepadConnected:Connect(function(Gamepad)
		InputModes.Gamepads:Enable()
		
		-- Bind thumbsticks
		Maid.InputChanged = UserInputService.InputChanged:Connect(function(InputObject)
			if InputObject.KeyCode.Name:find("Thumbstick") then
				if InputObject.Position.magnitude > InputModes.THUMBSTICK_DEADZONE then
					InputProcessor:Evaluate(InputObject)
				end
			end
		end)
	end))

	Maid:GiveTask(UserInputService.GamepadDisconnected:Connect(function(Gamepad)
		-- TODO: Stop assuming state is mouse/keyboard
		InputModes.Mouse:Enable()
		InputModes.Keyboard:Enable()
		
		Maid.InputChanged = nil
	end))
end


return InputModes