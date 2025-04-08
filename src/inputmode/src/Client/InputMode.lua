--!strict
--[=[
	Trace input mode state and trigger changes correctly. See [InputModeSelector] for details
	on how to select between these. See [InputModeTypeTypes] for predefined modes.

	@class InputMode
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local DuckTypeUtils = require("DuckTypeUtils")
local _InputModeType = require("InputModeType")

--[=[
	Fires off when the mode is enabled
	@prop Enabled Signal<()>
	@within InputMode
]=]

--[=[
	Name of the InputMode
	@prop Name Signal<()>
	@within InputMode
]=]

local InputMode = {}
InputMode.__index = InputMode
InputMode.ClassName = "InputMode"

export type InputMode = typeof(setmetatable(
	{} :: {
		_inputModeType: _InputModeType.InputModeType,
		_lastEnabled: number,
		Enabled: Signal.Signal<()>,
	},
	{} :: typeof({ __index = InputMode })
))

--[=[
	Constructs a new InputMode. This inherits data from the name.

	@param inputModeType InputModeType
	@return InputMode
]=]
function InputMode.new(inputModeType: _InputModeType.InputModeType): InputMode
	local self = setmetatable({}, InputMode)

	self._inputModeType = assert(inputModeType, "Bad inputModeType")

	self._lastEnabled = 0

	self.Name = self._inputModeType.Name
	self.Enabled = Signal.new()

	return self
end

--[=[
	Returns true if a given value is an InputMode
	@param value any
	@return boolean
]=]
function InputMode.isInputMode(value: any): boolean
	return DuckTypeUtils.isImplementation(InputMode, value)
end

--[=[
	Checks the last point this input mode was used.
	@return number
]=]
function InputMode.GetLastEnabledTime(self: InputMode): number
	return self._lastEnabled
end

--[=[
	Returns all keys defining the input mode.
	@return { UserInputType | KeyCode | string }
]=]
function InputMode.GetKeys(self: InputMode): { Enum.UserInputType | Enum.KeyCode | string }
	return self._inputModeType:GetKeys()
end

--[=[
	Checks the validity of the inputType
	@param inputType { UserInputType | KeyCode | string }
	@return boolean
]=]
function InputMode.IsValid(self: InputMode, inputType: _InputModeType.InputModeKey): boolean
	assert(inputType, "Must send in inputType")

	return self._inputModeType:IsValid(inputType)
end

--[=[
	Enables the mode
]=]
function InputMode.Enable(self: InputMode)
	self._lastEnabled = os.clock()
	self.Enabled:Fire()
end

--[=[
	Evaluates the input object, and if it's valid, enables the mode
	@param inputObject InputObject
]=]
function InputMode.Evaluate(self: InputMode, inputObject: InputObject)
	if self._inputModeType:IsValid(inputObject.UserInputType) or self._inputModeType:IsValid(inputObject.KeyCode) then
		self:Enable()
	end
end

--[=[
	Cleans up the input mode
]=]
function InputMode.Destroy(self: InputMode)
	self.Enabled:Destroy()
end

return InputMode