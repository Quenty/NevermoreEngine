---  Trace input mode state and trigger changes correctly
-- @classmod InputMode

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Signal = require("Signal")

local InputMode = {}
InputMode.__index = InputMode
InputMode.ClassName = "InputMode"

function InputMode.new(name)
	local self = setmetatable({}, InputMode)

	self._lastEnabled = 0
	self._valid = {}

	self.Name = name or "Unnamed"

	--- Fires off when the mode is enabled
	-- @signal Enabled
	self.Enabled = Signal.new()

	return self
end

function InputMode:GetLastEnabledTime()
	return self._lastEnabled
end

---
-- @param Keys A string for ease of use, or a table of keys
-- @param [EnumSet] The enum set to pull from. Defaults to KeyCode.
function InputMode:AddKeys(keys, enumSet)
	enumSet = enumSet or Enum.KeyCode

	if type(keys) == "string" then
		local newKeys = {}
		for key in keys:gmatch("%w+") do
			table.insert(newKeys, key)
		end
		keys = newKeys
	end

	for _, key in pairs(keys) do
		if type(key) == "string" then
			key = enumSet[key]
		end

		self._valid[key] = true
	end

	return self
end

function InputMode:AddInputMode(inputMode)
	for key, _ in pairs(inputMode._valid) do
		self._valid[key] = true
	end
	return self
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
	if self:IsValid(inputObject.UserInputType) or self:IsValid(inputObject.KeyCode) then
		self:Enable()
	end
end

return InputMode