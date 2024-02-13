--[=[
	Type specification for input modes, which is static. Separated out from InputMode which is dynamic.

	@class InputModeType
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

local InputModeType = {}
InputModeType.ClassName = "InputModeType"
InputModeType.__index = InputModeType

--[=[
	Constructs a new InputModeType

	@param name string
	@param typesAndInputModes { { UserInputType | KeyCode | string | InputMode } }
	@return InputMode
]=]
function InputModeType.new(name, typesAndInputModes)
	local self = setmetatable({}, InputModeType)

	self._valid = {}
	self._keys = {}
	self.Name = name or "Unnamed"

	self:_addValidTypesFromTable(typesAndInputModes)

	return self
end

--[=[
	Returns true if a given value is an InputModeType
	@param value any
	@return boolean
]=]
function InputModeType.isInputModeType(value)
	return DuckTypeUtils.isImplementation(InputModeType, value)
end

--[=[
	Checks the validity of the inputType
	@param inputType { UserInputType | KeyCode | string }
	@return boolean
]=]
function InputModeType:IsValid(inputType)
	assert(inputType, "Must send in inputType")

	return self._valid[inputType]
end

--[=[
	Returns all keys defining the input mode.
	@return { UserInputType | KeyCode | string }
]=]
function InputModeType:GetKeys()
	return self._keys
end

function InputModeType:_addValidTypesFromTable(keys)
	for _, key in pairs(keys) do
		if typeof(key) == "EnumItem" then
			if not self._valid[key] then
				self._valid[key] = true
				table.insert(self._keys, key)
			end
		elseif InputModeType.isInputModeType(key) then
			self:_addInputModeType(key)
		else
			warn(string.format("[InputModeType] - Invalid key of value %q of type %s", tostring(key), typeof(key)))
		end
	end
end

function InputModeType:_addInputModeType(inputModeType)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	for _, key in pairs(inputModeType._keys) do
		if not self._valid[key] then
			self._valid[key] = true
			table.insert(self._keys, key)
		end
	end
end



return InputModeType