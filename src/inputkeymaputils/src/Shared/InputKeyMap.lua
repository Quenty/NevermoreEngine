--[=[
	This represents a list of key bindings for a specific mode. While this is a useful object to query
	for showing icons and input hints to the user, in general, it is recommended that binding occur
	at the list level instead of at the input mode level. That way, if the user switches to another input
	mode then input is immediately processed.

	@class InputKeyMap
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local InputModeType = require("InputModeType")
local InputTypeUtils = require("InputTypeUtils")

local InputKeyMap = setmetatable({}, BaseObject)
InputKeyMap.ClassName = "InputKeyMap"
InputKeyMap.__index = InputKeyMap

--[=[
	Constructs a new InputKeyMap. Generally this would be sent immediately to an
	[InputKeyMapList]. This holds a list of key bindings for a specific type.

	@param inputModeType InputModeType
	@param inputTypes { InputType }
	@return InputKeyMap
]=]
function InputKeyMap.new(inputModeType, inputTypes)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")
	assert(type(inputTypes) == "table" or inputTypes == nil, "Bad inputTypes")

	local self = setmetatable(BaseObject.new(), InputKeyMap)

	self._inputModeType = assert(inputModeType, "No inputModeType")

	self._defaultInputTypes = inputTypes or {}

	self._inputType = self._maid:Add(ValueObject.new(self._defaultInputTypes))

	return self
end

--[=[
	Gets the input mode for this keymap. This will not change.
]=]
function InputKeyMap:GetInputModeType()
	return self._inputModeType
end

--[=[
	Sets the input types list for this input key map.

	@param inputTypes { InputType }
]=]
function InputKeyMap:SetInputTypesList(inputTypes)
	assert(type(inputTypes) == "table", "Bad inputTypes")

	self._inputType.Value = inputTypes
end

--[=[
	Sets the default input types list. This is whatever the game has, which is
	different than whatever the user has set.

	This will also set the current input type to be the same as the default if they
	are equivalent.

	@param inputTypes { InputType }
]=]
function InputKeyMap:SetDefaultInputTypesList(inputTypes)
	assert(type(inputTypes) == "table", "Bad inputTypes")
	assert(type(self._defaultInputTypes) == "table", "bad self._defaultInputTypes")

	if InputTypeUtils.areInputTypesListsEquivalent(self._inputType.Value, self._defaultInputTypes) then
		self._inputType.Value = inputTypes
	end

	self._defaultInputTypes = inputTypes
end

--[=[
	Gets the default input types list

	@return { InputType }
]=]
function InputKeyMap:GetDefaultInputTypesList()
	return self._defaultInputTypes
end

--[=[
	Resets the input type to the default input types.
]=]
function InputKeyMap:RestoreDefault()
	self._inputType.Value = self._defaultInputTypes
end

--[=[
	Observes the current list for the input key map list.

	@return Observable<{ InputType }>
]=]
function InputKeyMap:ObserveInputTypesList()
	return self._inputType:Observe()
end

--[=[
	Gets the input types list

	@return { InputType }
]=]
function InputKeyMap:GetInputTypesList()
	return self._inputType.Value
end

return InputKeyMap