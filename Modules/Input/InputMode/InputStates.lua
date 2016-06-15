local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary
local InputModeState    = LoadCustomLibrary("InputModeState")

local Maid              = LoadCustomLibrary("Maid").MakeMaid()

local InputStates = {}

-- Intent: Specific input states and Hotkey creation
-- Not pretty. 

setmetatable(InputStates, {
	__index = function(self, Key)
		error("'" .. tostring(Key) .. "' is not a valid InputState"); 
	end
});

local InputProcessor

local Keypad = "KeypadZero,KeypadOne,KeypadTwo,KeypadThree,KeypadFour,KeypadFive,KeypadSix,KeypadSeven,KeypadEight,KeypadNine,KeypadPeriod,KeypadDivide,KeypadMultiply,KeypadMinus,KeypadPlus,KeypadEnter,KeypadEquals"
local Alphabet = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
local ArrowKeys ="Left,Right,Up,Down"

InputStates.ArrowKeys = InputModeState.new():AddKeys(ArrowKeys, Enum.KeyCode);
InputStates.Keyboard = InputModeState.new()
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

InputStates.Touch = InputModeState.new():AddKeys("Touch", Enum.UserInputType)
-- Start out with no keytips if we don't have touch.
if UserInputService.TouchEnabled then
	InputStates.Touch:Enable()
end

InputStates.WASD = InputModeState.new():AddKeys("W,A,S,D", Enum.KeyCode)
InputStates.Gamepads = InputModeState.new()
	:AddKeys(GamepadThumbsticks, Enum.KeyCode)
	:AddKeys(GamepadButtons, Enum.KeyCode)
	:AddKeys(GamepadTriggers, Enum.KeyCode)
	:AddKeys("Gamepad1,Gamepad2,Gamepad3,Gamepad4", Enum.UserInputType)

local InputModeProcessor = LoadCustomLibrary("InputModeProcessor")
InputProcessor = InputModeProcessor.new()
	:AddState(InputStates.Keyboard)
	:AddState(InputStates.WASD)
	:AddState(InputStates.ArrowKeys)
	:AddState(InputStates.Gamepads)
	
UserInputService.InputBegan:connect(function(InputObject)
	InputProcessor:Evaluate(InputObject)
end)

UserInputService.GamepadConnected:connect(function(Gamepad)
	InputStates.Gamepads:Enable()
	
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
	InputStates.Keyboard:Enable()
	Maid.InputChanged = nil
end)

return InputStates