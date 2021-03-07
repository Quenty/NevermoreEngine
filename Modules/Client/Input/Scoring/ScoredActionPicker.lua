---
-- @classmod ScoredActionPicker
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Set = require("Set")

local MAX_ACTION_LIST_SIZE_BEFORE_WARN = 25

local ScoredActionPicker = setmetatable({}, BaseObject)
ScoredActionPicker.ClassName = "ScoredActionPicker"
ScoredActionPicker.__index = ScoredActionPicker

function ScoredActionPicker.new()
	local self = setmetatable(BaseObject.new(), ScoredActionPicker)

	self._actionSet = {}

	return self
end

function ScoredActionPicker:Update()
	if not next(self._actionSet) then
		return
	end

	local actionList = Set.toList(self._actionSet)
	table.sort(actionList, function(a, b)
		if a._score == b._score then
			-- Older objects have preference in ties
			return a._createdTimeStamp < b._createdTimeStamp
		else
			return a._score > b._score
		end
	end)

	if #actionList > MAX_ACTION_LIST_SIZE_BEFORE_WARN then
		warn(("[ScoredActionPicker.Update] - Action list has size of %d/%d")
			:format(#actionList, MAX_ACTION_LIST_SIZE_BEFORE_WARN))
	end

	for index, action in pairs(actionList) do
		action:SetRank(index)
	end
end

function ScoredActionPicker:AddAction(action)
	assert(type(action) == "table")

	self._actionSet[action] = true

	self._maid[action] = action.Removing:Connect(function()
		self:_removeAction(action)
	end)
end

function ScoredActionPicker:_removeAction(action)
	self._actionSet[action] = nil
	self._maid[action] = nil
end

return ScoredActionPicker