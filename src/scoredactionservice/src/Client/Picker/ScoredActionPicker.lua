--!strict
--[=[
	@class ScoredActionPicker
]=]

local require = require(script.Parent.loader).load(script)

local Set = require("Set")
local ValueObject = require("ValueObject")
local BaseObject = require("BaseObject")
local Maid = require("Maid")
local _ScoredAction = require("ScoredAction")

local MAX_ACTION_LIST_SIZE_BEFORE_WARN = 25

local ScoredActionPicker = setmetatable({}, BaseObject)
ScoredActionPicker.ClassName = "ScoredActionPicker"
ScoredActionPicker.__index = ScoredActionPicker

export type ScoredActionPicker = typeof(setmetatable(
	{} :: {
		_actionSet: { [_ScoredAction.ScoredAction]: boolean },
		_currentPreferred: ValueObject.ValueObject<_ScoredAction.ScoredAction?>,
	},
	{} :: typeof({ __index = ScoredActionPicker })
)) & BaseObject.BaseObject

function ScoredActionPicker.new()
	local self: ScoredActionPicker = setmetatable(BaseObject.new() :: any, ScoredActionPicker)

	self._actionSet = {}
	self._currentPreferred = self._maid:Add(ValueObject.new())

	self._maid:GiveTask(self._currentPreferred.Changed:Connect(function(new, _)
		local maid = Maid.new()

		if new and new.Destroy and self.Destroy then
			maid:GiveTask(new:PushPreferred())
		end

		self._maid._current = maid
	end))

	return self
end

function ScoredActionPicker.Update(self: ScoredActionPicker): ()
	if not next(self._actionSet) then
		self._currentPreferred.Value = nil
		return
	end

	local actionList: { _ScoredAction.ScoredAction } = Set.toList(self._actionSet)
	table.sort(actionList, function(a, b)
		if a._score == b._score then
			-- Older objects have preference in ties
			return a._createdTimeStamp < b._createdTimeStamp
		else
			return a._score > b._score
		end
	end)

	if #actionList > MAX_ACTION_LIST_SIZE_BEFORE_WARN then
		warn(
			string.format(
				"[ScoredActionPicker.Update] - Action list has size of %d/%d",
				#actionList,
				MAX_ACTION_LIST_SIZE_BEFORE_WARN
			)
		)
	end

	for _, action: any in actionList do
		local preferredAction = self:_tryGetValidPreferredAction(action)
		if preferredAction then
			self._currentPreferred.Value = preferredAction
			break
		end
	end
end

function ScoredActionPicker._tryGetValidPreferredAction(
	_self: ScoredActionPicker,
	action: _ScoredAction.ScoredAction
): _ScoredAction.ScoredAction?
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

function ScoredActionPicker.AddAction(self: ScoredActionPicker, action: _ScoredAction.ScoredAction): ()
	assert(type(action) == "table", "Bad action")

	self._actionSet[action] = true
	self:Update()
end

function ScoredActionPicker.RemoveAction(self: ScoredActionPicker, action: _ScoredAction.ScoredAction): ()
	assert(type(action) == "table", "Bad action")

	if self._currentPreferred.Value == action then
		self._currentPreferred.Value = nil
	end

	self._actionSet[action] = nil
	self:Update()
end

function ScoredActionPicker.HasActions(self: ScoredActionPicker): boolean
	return next(self._actionSet) ~= nil
end

return ScoredActionPicker