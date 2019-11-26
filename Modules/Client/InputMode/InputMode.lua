---  Trace input mode state and trigger changes correctly
-- @classmod InputMode

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Signal = require("Signal")

local InputMode = {}
InputMode.__index = InputMode
InputMode.ClassName = "InputMode"

function InputMode.new(name, typesAndInputModes)
	local self = setmetatable({}, InputMode)

	self._lastEnabled = 0
	self._valid = {}

	self.Name = name or "Unnamed"

	--- Fires off when the mode is enabled
	-- @signal Enabled
	self.Enabled = Signal.new()

	self:_addValidTypesFromTable(typesAndInputModes)

	return self
end

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
	assert(inputMode.ClassName == "InputMode")

	for key, _ in pairs(inputMode._valid) do
		self._valid[key] = true
	end
end

function InputMode:GetKeys()
	local keys = {}
	for key, _ in pairs(self._valid) do
		table.insert(keys, key)
	end
	return keys
end

---
-- @param inputType May be a UserInputType or KeyCode
function InputMode:IsValid(inputType)
	assert(inputType, "Must send in inputType")

	return self._valid[inputType]
end

--- Enables the mode
function InputMode:Enable()
	self._lastEnabled = tick()
	self.Enabled:Fire()
end

--- Evaluates the input object, and if it's valid, enables the mode
function InputMode:Evaluate(inputObject)
	if self._valid[inputObject.UserInputType]
		or self._valid[inputObject.KeyCode] then

		self:Enable()
	end
end

return InputMode