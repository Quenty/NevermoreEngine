local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local InputModeState = LoadCustomLibrary("InputModeState")

local DefaultInputStates = {}
local Maid = LoadCustomLibrary("Maid").MakeMaid()

-- Intent: Specific input states

setmetatable(DefaultInputStates, {
	__index = function(self, Key)
		error(("'%s' is not a valid InputState"):format(tostring(Key))); 
	end
});

local Keypad = "KeypadZero,KeypadOne,KeypadTwo,KeypadThree,KeypadFour,KeypadFive,KeypadSix,KeypadSeven,KeypadEight,KeypadNine,KeypadPeriod,KeypadDivide,KeypadMultiply,KeypadMinus,KeypadPlus,KeypadEnter,KeypadEquals"
local Alphabet = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
local ArrowKeys = "Left,Right,Up,Down"

DefaultInputStates.ArrowKeys = InputModeState.new():AddKeys(ArrowKeys, Enum.KeyCode);
DefaultInputStates.Keyboard = InputModeState.new()
	:AddKeys("Keyboard", Enum.UserInputType) -- Incase we miss anything
	:AddKeys("Backspace,Tab,Clear,Return,Pause,Escape,Space,QuotedDouble,Hash,Dollar,Percent,Ampersand,Quote,LeftParenthesis,RightParenthesis,Asterisk,Plus,Comma,Minus,Period,Slash,Zero,One,Two,Three,Four,Five,Six,Seven,Eight,Nine,Colon,Semicolon,LessThan,Equals,GreaterThan,Question,At,LeftBracket,BackSlash,RightBracket,Caret,Underscore,Backquote", Enum.KeyCode)
	:AddKeys(Alphabet, Enum.KeyCode)
	:AddKeys("LeftCurly,Pipe,RightCurly,Tilde,Delete,Insert,Home,End,PageUp,PageDown,F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12,F13,F14", Enum.KeyCode)
	:AddKeys("NumLock,CapsLock,ScrollLock,RightShift,LeftShift,RightControl,LeftControl,RightAlt,LeftAlt,RightMeta,LeftMeta,LeftSuper,RightSuper,Mode,Compose,Help,Print,SysReq,Break", Enum.KeyCode)
	:AddKeys(Keypad, Enum.KeyCode)
	:AddKeys(ArrowKeys)

-- Did not include: Menu,Power,Euro,Undo

local GamepadThumbsticks = "Thumbstick1,Thumbstick2"
local GamepadTriggers = "ButtonR2,ButtonL2,ButtonR1,ButtonL1"
local GamepadButtons = "ButtonA,ButtonB,ButtonX,ButtonY,ButtonR3,ButtonL3,ButtonStart,ButtonSelect,DPadLeft,DPadRight,DPadUp,DPadDown"

DefaultInputStates.Touch = InputModeState.new():AddKeys("Touch", Enum.UserInputType)


DefaultInputStates.WASD = InputModeState.new():AddKeys("W,A,S,D", Enum.KeyCode)
DefaultInputStates.Gamepads = InputModeState.new()
	:AddKeys(GamepadThumbsticks, Enum.KeyCode)
	:AddKeys(GamepadButtons, Enum.KeyCode)
	:AddKeys(GamepadTriggers, Enum.KeyCode)
	:AddKeys("Gamepad1,Gamepad2,Gamepad3,Gamepad4,Gamepad5,Gamepad6,Gamepad7,Gamepad8", Enum.UserInputType)
DefaultInputStates.Mouse = InputModeState.new():AddKeys("MouseButton1,MouseButton2,MouseButton3,MouseWheel,MouseMovement", Enum.UserInputType);

local InputModeProcessor = LoadCustomLibrary("InputModeProcessor")
local InputProcessor = InputModeProcessor.new()
	:AddState(DefaultInputStates.Keyboard)
	:AddState(DefaultInputStates.WASD)
	:AddState(DefaultInputStates.ArrowKeys)
	:AddState(DefaultInputStates.Gamepads)
	:AddState(DefaultInputStates.Mouse)
	
UserInputService.InputBegan:connect(function(InputObject)
	InputProcessor:Evaluate(InputObject)
end)

if UserInputService.TouchEnabled then
	DefaultInputStates.Touch:Enable()
end
if UserInputService.KeyboardEnabled then
	DefaultInputStates.Keyboard:Enable()
end
if UserInputService.MouseEnabled then
	DefaultInputStates.Mouse:Enable()
end
if UserInputService.GamepadEnabled then
	DefaultInputStates.Gamepads:Enable()
end
if GuiService:IsTenFootInterface() then
	DefaultInputStates.Gamepads:Enable()
end

UserInputService.GamepadConnected:connect(function(Gamepad)
	DefaultInputStates.Gamepads:Enable()
	
	-- Bind thumbsticks
	local ThumbstickDeadzone = 0.14
	Maid.InputChanged = UserInputService.InputChanged:connect(function(InputObject)
		if InputObject.KeyCode.Name:find("Thumbstick") then
			if InputObject.Position.magnitude > ThumbstickDeadzone then
				InputProcessor:Evaluate(InputObject)
			end
		end
	end)
end)

UserInputService.GamepadDisconnected:connect(function(Gamepad)	
	-- Assumed state:
	DefaultInputStates.Mouse:Enable()
	DefaultInputStates.Keyboard:Enable()
	
	Maid.InputChanged = nil
end)

return DefaultInputStates