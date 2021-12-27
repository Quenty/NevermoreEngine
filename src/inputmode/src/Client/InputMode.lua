--[=[
	Trace input mode state and trigger changes correctly. See [InputModeSelector] for details
	on how to select between these. See [INPUT_MODES] for predefined modes.

	@class InputMode
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")

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

--[=[
	Constructs a new InputMode

	@param name string
	@param typesAndInputModes { { UserInputType | KeyCode | string | InputMode } }
	@return InputMode
]=]
function InputMode.new(name, typesAndInputModes)
	local self = setmetatable({}, InputMode)

	self._lastEnabled = 0
	self._valid = {}

	self.Name = name or "Unnamed"
	self.Enabled = Signal.new()

	self:_addValidTypesFromTable(typesAndInputModes)

	return self
end

--[=[
	Checks the last point this input mode was used.
	@return number
]=]
function InputMode:GetLastEnabledTime()
	return self._lastEnabled
end

function InputMode:_addValidTypesFromTable(keys)
	for _, key in pairs(keys) do
		if typeof(key) == "EnumItem" then
			self._valid[key] = true
		elseif type(key) == "table" then
			self:_addInputMode(key)
		end
	end
end

function InputMode:_addInputMode(inputMode)
	assert(inputMode.ClassName == "InputMode", "bad inputMode")

	for key, _ in pairs(inputMode._valid) do
		self._valid[key] = true
	end
end

--[=[
	Returns all keys defining the input mode.
	@return { UserInputType | KeyCode | string }
]=]
function InputMode:GetKeys()
	local keys = {}
	for key, _ in pairs(self._valid) do
		table.insert(keys, key)
	end
	return keys
end

--[=[
	Checks the validity of the inputType
	@param inputType { UserInputType | KeyCode | string }
	@return boolean
]=]
function InputMode:IsValid(inputType)
	assert(inputType, "Must send in inputType")

	return self._valid[inputType]
end

--[=[
	Enables the mode
]=]
function InputMode:Enable()
	self._lastEnabled = tick()
	self.Enabled:Fire()
end

--[=[
	Evaluates the input object, and if it's valid, enables the mode
	@param inputObject InputObject
]=]
function InputMode:Evaluate(inputObject)
	if self._valid[inputObject.UserInputType]
		or self._valid[inputObject.KeyCode] then

		self:Enable()
	end
end

return InputMode