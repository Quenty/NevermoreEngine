---
-- @classmod ScoredActionPicker
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Set = require("Set")
local ValueObject = require("ValueObject")
local BaseObject = require("BaseObject")

local MAX_ACTION_LIST_SIZE_BEFORE_WARN = 25

local ScoredActionPicker = setmetatable({},BaseObject)
ScoredActionPicker.ClassName = "ScoredActionPicker"
ScoredActionPicker.__index = ScoredActionPicker

function ScoredActionPicker.new()
	local self = setmetatable(BaseObject.new(), ScoredActionPicker)

	self._actionSet = {}

	self._currentPreferred = ValueObject.new()
	self._maid:GiveTask(self._currentPreferred)

	self._maid:GiveTask(self._currentPreferred.Changed:Connect(function(new, old, maid)
		if new then
			maid:GiveTask(new:PushPreferred())
		end
	end))

	return self
end

function ScoredActionPicker:Update()
	if not next(self._actionSet) then
		self._currentPreferred.Value = nil
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

	self._currentPreferred.Value = self:_tryGetValidPreferredAction(actionList[1])
end

function ScoredActionPicker:_tryGetValidPreferredAction(action)
	if not action then
		return nil
	end

	if not action.Destroy then
		warn("[ScoredActionPicker] - Action is destroyed. Should have been removed.")
		return nil
	end

	if action:GetScore() == -math.huge then
		return nil
	end

	return action
end

function ScoredActionPicker:AddAction(action)
	assert(type(action) == "table")

	self._actionSet[action] = true
end

function ScoredActionPicker:RemoveAction(action)
	assert(type(action) == "table")

	if self._currentPreferred.Value == action then
		self._currentPreferred.Value = nil
	end

	self._actionSet[action] = nil
end

function ScoredActionPicker:HasActions()
	return next(self._actionSet) ~= nil
end

return ScoredActionPicker