--[=[
	Type specification for input modes, which is static. Separated out from InputMode which is dynamic.

	@class InputModeType
]=]

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
	return type(value) == "table" and getmetatable(value) == InputModeType
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
	local keys = {}
	for key, _ in pairs(self._valid) do
		table.insert(keys, key)
	end
	return keys
end

function InputModeType:_addValidTypesFromTable(keys)
	for _, key in pairs(keys) do
		if typeof(key) == "EnumItem" then
			self._valid[key] = true
		elseif InputModeType.isInputModeType(key) then
			self:_addInputModeType(key)
		end
	end
end

function InputModeType:_addInputModeType(inputModeType)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	for key, _ in pairs(inputModeType._valid) do
		self._valid[key] = true
	end
end



return InputModeType