--!strict
--[=[
	@class ScoredActionPickerProvider
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ScoredActionPicker = require("ScoredActionPicker")
local Table = require("Table")
local TouchButtonScoredActionPicker = require("TouchButtonScoredActionPicker")
local InputTypeUtils = require("InputTypeUtils")

local MAX_ACTION_LIST_SIZE_BEFORE_WARN = 25

local ScoredActionPickerProvider = setmetatable({}, BaseObject)
ScoredActionPickerProvider.ClassName = "ScoredActionPickerProvider"
ScoredActionPickerProvider.__index = ScoredActionPickerProvider

type ActionPicker = {
	Update: (unknown) -> (),
	HasActions: (unknown) -> boolean,
}

export type ScoredActionPickerProvider = typeof(setmetatable(
	{} :: {
		_scoredActionPickers: { [any]: ActionPicker },
	},
	{} :: typeof({ __index = ScoredActionPickerProvider })
)) & BaseObject.BaseObject

function ScoredActionPickerProvider.new(): ScoredActionPickerProvider
	local self: ScoredActionPickerProvider = setmetatable(BaseObject.new() :: any, ScoredActionPickerProvider)

	self._scoredActionPickers = {} -- [ key ] = picker

	return self
end

function ScoredActionPickerProvider.FindPicker(self: ScoredActionPickerProvider, inputType): ActionPicker
	local key = InputTypeUtils.getUniqueKeyForInputType(inputType)
	return self._scoredActionPickers[key]
end

--inputType is most likely an enum, but could be a string!
function ScoredActionPickerProvider.GetOrCreatePicker(self: ScoredActionPickerProvider, inputType): ActionPicker
	assert(inputType, "Bad inputType")
	local key = InputTypeUtils.getUniqueKeyForInputType(inputType)

	if self._scoredActionPickers[key] then
		return self._scoredActionPickers[key]
	end

	local picker: ActionPicker
	if inputType == "TouchButton" then
		picker = TouchButtonScoredActionPicker.new() :: any
	else
		picker = ScoredActionPicker.new() :: any
	end

	self._maid[key] = picker
	self._scoredActionPickers[key] = picker

	local amount = Table.count(self._scoredActionPickers)
	if amount > MAX_ACTION_LIST_SIZE_BEFORE_WARN then
		warn(
			string.format(
				"[ScoredActionPickerProvider.GetPicker] - Pickers has size of %d/%d",
				amount,
				MAX_ACTION_LIST_SIZE_BEFORE_WARN
			)
		)
	end

	return picker
end

function ScoredActionPickerProvider.Update(self: ScoredActionPickerProvider): ()
	local indexToRemove = {}
	for key, picker in self._scoredActionPickers do
		picker:Update()

		if not picker:HasActions() then
			table.insert(indexToRemove, key)
		end
	end

	for _, key in indexToRemove do
		self._scoredActionPickers[key] = nil
		self._maid[key] = nil
	end
end

return ScoredActionPickerProvider