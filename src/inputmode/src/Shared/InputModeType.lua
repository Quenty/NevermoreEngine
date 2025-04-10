--!strict
--[=[
	Type specification for input modes, which is static. Separated out from InputMode which is dynamic.

	@class InputModeType
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

local InputModeType = {}
InputModeType.ClassName = "InputModeType"
InputModeType.__index = InputModeType

export type InputModeType = typeof(setmetatable(
	{} :: {
		_keys: { any },
		_valid: { [any]: boolean },
		Name: string,
	},
	{} :: typeof({ __index = InputModeType })
))

export type InputModeKey = Enum.UserInputType | Enum.KeyCode | string
export type InputModeTypeDefinition = { InputModeType | InputModeKey }

--[=[
	Constructs a new InputModeType

	@param name string
	@param typesAndInputModeTypes { Enum.UserInputType | Enum.KeyCode | string | InputModeType }
	@return InputMode
]=]
function InputModeType.new(name: string, typesAndInputModeTypes: InputModeTypeDefinition)
	local self = setmetatable({}, InputModeType)

	self._valid = {}
	self._keys = {}
	self.Name = name or "Unnamed"

	self:_addValidTypesFromTable(typesAndInputModeTypes)

	return self
end

--[=[
	Returns true if a given value is an InputModeType
	@param value any
	@return boolean
]=]
function InputModeType.isInputModeType(value: any): boolean
	return DuckTypeUtils.isImplementation(InputModeType, value)
end

--[=[
	Checks the validity of the inputType
	@param inputType { UserInputType | KeyCode | string }
	@return boolean
]=]
function InputModeType.IsValid(self: InputModeType, inputType: InputModeKey): boolean
	assert(inputType, "Must send in inputType")

	return self._valid[inputType]
end

--[=[
	Returns all keys defining the input mode.
	@return { UserInputType | KeyCode | string }
]=]
function InputModeType.GetKeys(self: InputModeType): { InputModeKey }
	return self._keys
end

function InputModeType._addValidTypesFromTable(self: InputModeType, keys: { InputModeKey | InputModeType })
	for _, key in keys do
		if typeof(key) == "EnumItem" then
			if not self._valid[key] then
				self._valid[key] = true
				table.insert(self._keys, key)
			end
		elseif InputModeType.isInputModeType(key) then
			self:_addInputModeType(key :: any)
		else
			warn(string.format("[InputModeType] - Invalid key of value %q of type %s", tostring(key), typeof(key)))
		end
	end
end

function InputModeType._addInputModeType(self: InputModeType, inputModeType: InputModeType)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	for _, key in inputModeType._keys do
		if not self._valid[key] then
			self._valid[key] = true
			table.insert(self._keys, key)
		end
	end
end

return InputModeType