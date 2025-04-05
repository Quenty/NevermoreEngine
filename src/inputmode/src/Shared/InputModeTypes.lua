--!strict
--[=[
	Holds all the input mode type configuration, accessible on both the server and the client for keybinding validations.
	@class InputModeTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")
local InputModeType = require("InputModeType")

local InputModeTypes = {}

--[=[
	Input from a keypad
	@prop Keypad InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.Keypad = InputModeType.new("Keypad", {
	Enum.KeyCode.KeypadZero,
	Enum.KeyCode.KeypadOne,
	Enum.KeyCode.KeypadTwo,
	Enum.KeyCode.KeypadThree,
	Enum.KeyCode.KeypadFour,
	Enum.KeyCode.KeypadFive,
	Enum.KeyCode.KeypadSix,
	Enum.KeyCode.KeypadSeven,
	Enum.KeyCode.KeypadEight,
	Enum.KeyCode.KeypadNine,
	Enum.KeyCode.KeypadPeriod,
	Enum.KeyCode.KeypadDivide,
	Enum.KeyCode.KeypadMultiply,
	Enum.KeyCode.KeypadMinus,
	Enum.KeyCode.KeypadPlus,
	Enum.KeyCode.KeypadEnter,
	Enum.KeyCode.KeypadEquals,
})

--[=[
	Input from a keyboard
	@prop Keyboard InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.Keyboard = InputModeType.new("Keyboard", {
	Enum.UserInputType.Keyboard,

	-- Other input modes
	InputModeTypes.Keypad,

	-- Valid KeyCodes for input binding
	Enum.KeyCode.Backspace,
	Enum.KeyCode.Tab,
	Enum.KeyCode.Clear,
	Enum.KeyCode.Return,
	Enum.KeyCode.Pause,
	Enum.KeyCode.Escape,
	Enum.KeyCode.Space,
	Enum.KeyCode.QuotedDouble,
	Enum.KeyCode.Hash,
	Enum.KeyCode.Dollar,
	Enum.KeyCode.Percent,
	Enum.KeyCode.Ampersand,
	Enum.KeyCode.Quote,
	Enum.KeyCode.LeftParenthesis,
	Enum.KeyCode.RightParenthesis,
	Enum.KeyCode.Asterisk,
	Enum.KeyCode.Plus,
	Enum.KeyCode.Comma,
	Enum.KeyCode.Minus,
	Enum.KeyCode.Period,
	Enum.KeyCode.Slash,
	Enum.KeyCode.Zero,
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.Colon,
	Enum.KeyCode.Semicolon,
	Enum.KeyCode.LessThan,
	Enum.KeyCode.Equals,
	Enum.KeyCode.GreaterThan,
	Enum.KeyCode.Question,
	Enum.KeyCode.At,
	Enum.KeyCode.LeftBracket,
	Enum.KeyCode.BackSlash,
	Enum.KeyCode.RightBracket,
	Enum.KeyCode.Caret,
	Enum.KeyCode.Underscore,
	Enum.KeyCode.Backquote,
	Enum.KeyCode.A,
	Enum.KeyCode.B,
	Enum.KeyCode.C,
	Enum.KeyCode.D,
	Enum.KeyCode.E,
	Enum.KeyCode.F,
	Enum.KeyCode.G,
	Enum.KeyCode.H,
	Enum.KeyCode.I,
	Enum.KeyCode.J,
	Enum.KeyCode.K,
	Enum.KeyCode.L,
	Enum.KeyCode.M,
	Enum.KeyCode.N,
	Enum.KeyCode.O,
	Enum.KeyCode.P,
	Enum.KeyCode.Q,
	Enum.KeyCode.R,
	Enum.KeyCode.S,
	Enum.KeyCode.T,
	Enum.KeyCode.U,
	Enum.KeyCode.V,
	Enum.KeyCode.W,
	Enum.KeyCode.X,
	Enum.KeyCode.Y,
	Enum.KeyCode.Z,
	Enum.KeyCode.LeftCurly,
	Enum.KeyCode.Pipe,
	Enum.KeyCode.RightCurly,
	Enum.KeyCode.Tilde,
	Enum.KeyCode.Delete,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Right,
	Enum.KeyCode.Left,
	Enum.KeyCode.Insert,
	Enum.KeyCode.Home,
	Enum.KeyCode.End,
	Enum.KeyCode.PageUp,
	Enum.KeyCode.PageDown,
	Enum.KeyCode.F1,
	Enum.KeyCode.F2,
	Enum.KeyCode.F3,
	Enum.KeyCode.F4,
	Enum.KeyCode.F5,
	Enum.KeyCode.F6,
	Enum.KeyCode.F7,
	Enum.KeyCode.F8,
	Enum.KeyCode.F9,
	Enum.KeyCode.F10,
	Enum.KeyCode.F11,
	Enum.KeyCode.F12,
	Enum.KeyCode.F13,
	Enum.KeyCode.F14,
	Enum.KeyCode.F15,
	Enum.KeyCode.NumLock,
	Enum.KeyCode.CapsLock,
	Enum.KeyCode.ScrollLock,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightAlt,
	Enum.KeyCode.LeftAlt,
	Enum.KeyCode.RightMeta,
	Enum.KeyCode.LeftMeta,
	Enum.KeyCode.LeftSuper,
	Enum.KeyCode.RightSuper,
	Enum.KeyCode.Mode,
	Enum.KeyCode.Compose,
	Enum.KeyCode.Help,
	Enum.KeyCode.Print,
	Enum.KeyCode.SysReq,
	Enum.KeyCode.Break,
	Enum.KeyCode.Menu,
	Enum.KeyCode.Power,
	Enum.KeyCode.Euro,
	Enum.KeyCode.Undo,
})

--[=[
	Input involving arrow keys!
	@prop ArrowKeys InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.ArrowKeys = InputModeType.new("ArrowKeys", {
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
})

--[=[
	Input involving WASD
	@prop WASD InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.WASD = InputModeType.new("WASD", {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
})

--[=[
	Input involving the mouse
	@prop Mouse InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.Mouse = InputModeType.new("Mouse", {
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseButton3,
	Enum.UserInputType.MouseWheel,
	Enum.UserInputType.MouseMovement,
})

--[=[
	Input involving the keyboard OR mouse.
	@prop KeyboardAndMoues InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.KeyboardAndMouse = InputModeType.new("KeyboardAndMouse", {
	InputModeTypes.Mouse,
	InputModeTypes.Keyboard,
})

--[=[
	Input involving touch input.
	@prop Touch InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.Touch = InputModeType.new("Touch", {
	Enum.UserInputType.Touch,
})

--[=[
	@prop DPad InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.DPad = InputModeType.new("DPad", {
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadRight,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadDown,
})

--[=[
	Input involved thumbsticks.
	@prop Thumbsticks InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.Thumbsticks = InputModeType.new("Thumbsticks", {
	Enum.KeyCode.Thumbstick1,
	Enum.KeyCode.Thumbstick2,
})

--[=[
	Input involving gamepads
	@prop Gamepads InputModeType
	@readonly
	@within InputModeTypes
]=]
InputModeTypes.Gamepads = InputModeType.new("Gamepads", {
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
	Enum.UserInputType.Gamepad5,
	Enum.UserInputType.Gamepad6,
	Enum.UserInputType.Gamepad7,
	Enum.UserInputType.Gamepad8,

	-- Valid KeyCodes for input binding
	Enum.KeyCode.ButtonX,
	Enum.KeyCode.ButtonY,
	Enum.KeyCode.ButtonA,
	Enum.KeyCode.ButtonB,
	Enum.KeyCode.ButtonR1,
	Enum.KeyCode.ButtonL1,
	Enum.KeyCode.ButtonR2,
	Enum.KeyCode.ButtonL2,
	Enum.KeyCode.ButtonR3,
	Enum.KeyCode.ButtonL3,
	Enum.KeyCode.ButtonStart,
	Enum.KeyCode.ButtonSelect,
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadRight,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadDown,
})

export type InputModeTypes = {
	Keypad: InputModeType.InputModeType,
	Keyboard: InputModeType.InputModeType,
	ArrowKeys: InputModeType.InputModeType,
	WASD: InputModeType.InputModeType,
	Mouse: InputModeType.InputModeType,
	KeyboardAndMouse: InputModeType.InputModeType,
	Touch: InputModeType.InputModeType,
	DPad: InputModeType.InputModeType,
	Thumbsticks: InputModeType.InputModeType,
	Gamepads: InputModeType.InputModeType,
}

return Table.readonly(InputModeTypes :: InputModeTypes)
