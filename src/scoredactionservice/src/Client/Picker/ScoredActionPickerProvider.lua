--[=[
	@class ScoredActionPickerProvider
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ScoredActionPicker = require("ScoredActionPicker")
local Table = require("Table")
local TouchButtonScoredActionPicker = require("TouchButtonScoredActionPicker")
local InputKeyMapUtils = require("InputKeyMapUtils")

local MAX_ACTION_LIST_SIZE_BEFORE_WARN = 25

local ScoredActionPickerProvider = setmetatable({}, BaseObject)
ScoredActionPickerProvider.ClassName = "ScoredActionPickerProvider"
ScoredActionPickerProvider.__index = ScoredActionPickerProvider

function ScoredActionPickerProvider.new()
	local self = setmetatable(BaseObject.new(), ScoredActionPickerProvider)

	self._scoredActionPickers = {} -- [ key ] = picker

	return self
end

function ScoredActionPickerProvider:FindPicker(inputType)
	local key = InputKeyMapUtils.getUniqueKeyForInputType(inputType)
	return self._scoredActionPickers[key]
end

--inputType is most likely an enum, but could be a string!
function ScoredActionPickerProvider:GetOrCreatePicker(inputType)
	assert(inputType, "Bad inputType")
	local key = InputKeyMapUtils.getUniqueKeyForInputType(inputType)

	if self._scoredActionPickers[key] then
		return self._scoredActionPickers[key]
	end

	local picker
	if inputType == "TouchButton" then
		picker = TouchButtonScoredActionPicker.new()
	else
		picker = ScoredActionPicker.new()
	end

	self._maid[key] = picker
	self._scoredActionPickers[key] = picker

	local amount = Table.count(self._scoredActionPickers)
	if amount > MAX_ACTION_LIST_SIZE_BEFORE_WARN then
		warn(("[ScoredActionPickerProvider.GetPicker] - Pickers has size of %d/%d")
			:format(#amount, MAX_ACTION_LIST_SIZE_BEFORE_WARN))
	end

	return picker
end

function ScoredActionPickerProvider:Update()
	local indexToRemove = {}
	for key, picker in pairs(self._scoredActionPickers) do
		picker:Update()

		if not picker:HasActions() then
			table.insert(indexToRemove, key)
		end
	end

	for _, key in pairs(indexToRemove) do
		self._scoredActionPickers[key] = nil
		self._maid[key] = nil
	end
end

return ScoredActionPickerProvider