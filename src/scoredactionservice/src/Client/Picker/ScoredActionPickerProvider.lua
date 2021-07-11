---
-- @classmod ScoredActionPickerProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local ScoredActionPicker = require("ScoredActionPicker")
local Table = require("Table")

local MAX_ACTION_LIST_SIZE_BEFORE_WARN = 25

local ScoredActionPickerProvider = setmetatable({}, BaseObject)
ScoredActionPickerProvider.ClassName = "ScoredActionPickerProvider"
ScoredActionPickerProvider.__index = ScoredActionPickerProvider

function ScoredActionPickerProvider.new()
	local self = setmetatable(BaseObject.new(), ScoredActionPickerProvider)

	self._scoredActionPickers = {} -- [ category ] = picker

	return self
end

function ScoredActionPickerProvider:FindPicker(inputType)
	return self._scoredActionPickers[inputType]
end

--inputType is most likely an enum, but could be a string!
function ScoredActionPickerProvider:GetOrCreatePicker(inputType)
	assert(inputType)

	if self._scoredActionPickers[inputType] then
		return self._scoredActionPickers[inputType]
	end

	local picker = ScoredActionPicker.new()
	self._maid[inputType] = picker
	self._scoredActionPickers[inputType] = picker

	local amount = Table.count(self._scoredActionPickers)
	if amount > MAX_ACTION_LIST_SIZE_BEFORE_WARN then
		warn(("[ScoredActionPickerProvider.GetPicker] - Pickers has size of %d/%d")
			:format(#amount, MAX_ACTION_LIST_SIZE_BEFORE_WARN))
	end

	return picker
end

function ScoredActionPickerProvider:Update()
	local indexToRemove = {}
	for index, picker in pairs(self._scoredActionPickers) do
		picker:Update()

		if not picker:HasActions() then
			table.insert(indexToRemove, index)
		end
	end

	for _, index in pairs(indexToRemove) do
		self._scoredActionPickers[index] = nil
		self._maid[index] = nil
	end
end

return ScoredActionPickerProvider