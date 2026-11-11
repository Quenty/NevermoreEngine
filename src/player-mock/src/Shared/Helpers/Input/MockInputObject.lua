--!strict
--[=[
	Stand-in `InputObject` for [PlayerMock.fireInput] to hand a bound action, a real one not being
	`Instance.new`-able.

	Only the fields are own-keys, so an instance handed to [PlayerMock.fireServiceSignal] still
	crosses the `BindableEvent` boundary with its values intact -- the methods, like any metatable, do
	not survive that copy.

	Use [PlayerMock.makeInputObject].

	@class MockInputObject
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")
local Signal = require("Signal")

local MockInputObject = {}
MockInputObject.ClassName = "MockInputObject"
MockInputObject.__index = MockInputObject

export type InputObjectProps = {
	UserInputType: Enum.UserInputType?,
	KeyCode: Enum.KeyCode?,
	UserInputState: Enum.UserInputState?,
	Position: Vector3?,
	Delta: Vector3?,
}

export type MockInputObject = typeof(setmetatable(
	{} :: {
		UserInputType: Enum.UserInputType,
		KeyCode: Enum.KeyCode,
		UserInputState: Enum.UserInputState,
		Position: Vector3,
		Delta: Vector3,
		_signals: { [string]: Signal.Signal<()> },
	},
	{} :: typeof({ __index = MockInputObject })
))

--[=[
	Constructs a stand-in input object, defaulting every unspecified field.

	Use [PlayerMock.makeInputObject].

	@param props InputObjectProps?
	@return MockInputObject
]=]
function MockInputObject.new(props: InputObjectProps?): MockInputObject
	local resolved: InputObjectProps = props or {}
	if resolved.UserInputType ~= nil then
		assert(EnumUtils.isOfType(Enum.UserInputType, resolved.UserInputType))
	end

	local self: MockInputObject = setmetatable({} :: any, MockInputObject)

	self.UserInputType = resolved.UserInputType or Enum.UserInputType.Keyboard
	self.KeyCode = resolved.KeyCode or Enum.KeyCode.None
	self.UserInputState = resolved.UserInputState or Enum.UserInputState.Begin
	self.Position = resolved.Position or Vector3.zero
	self.Delta = resolved.Delta or Vector3.zero
	self._signals = {}

	return self
end

--[=[
	Returns the signal that fires when the given property changes, the same signal every time.
	Mirrors `InputObject:GetPropertyChangedSignal(propertyName)`.

	@param propertyName string
	@return Signal<()>
]=]
function MockInputObject.GetPropertyChangedSignal(self: MockInputObject, propertyName: string): Signal.Signal<()>
	assert(type(propertyName) == "string", "Bad propertyName")

	local existing = self._signals[propertyName]
	if existing then
		return existing
	end

	local signal = Signal.new()
	self._signals[propertyName] = signal
	return signal
end

--[=[
	Sets `UserInputState` and fires its changed signal, which is how a test drives the press
	lifecycle -- ending a press the engine would have ended itself.

	@param userInputState Enum.UserInputState
]=]
function MockInputObject.SetUserInputState(self: MockInputObject, userInputState: Enum.UserInputState): ()
	assert(EnumUtils.isOfType(Enum.UserInputState, userInputState))

	self.UserInputState = userInputState
	MockInputObject.GetPropertyChangedSignal(self, "UserInputState"):Fire()
end

return MockInputObject
