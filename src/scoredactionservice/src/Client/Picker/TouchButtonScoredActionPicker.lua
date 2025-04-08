--!strict
--[=[
	We need to handle touch buttons separately because we may have as many of these as we want.
	@class TouchButtonScoredActionPicker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local TouchButtonScoredActionPicker = setmetatable({}, BaseObject)
TouchButtonScoredActionPicker.ClassName = "TouchButtonScoredActionPicker"
TouchButtonScoredActionPicker.__index = TouchButtonScoredActionPicker

export type TouchButtonScoredActionPicker = typeof(setmetatable(
	{} :: {
		_actionSet: { [any]: boolean },
	},
	{} :: typeof({ __index = TouchButtonScoredActionPicker })
)) & BaseObject.BaseObject

function TouchButtonScoredActionPicker.new(): TouchButtonScoredActionPicker
	local self: TouchButtonScoredActionPicker = setmetatable(BaseObject.new() :: any, TouchButtonScoredActionPicker)

	self._actionSet = {}

	return self
end

function TouchButtonScoredActionPicker.Update(self: TouchButtonScoredActionPicker): ()
	for action, _ in self._actionSet do
		if not action.Destroy then
			warn("[ScoredActionPicker] - Action is destroyed. Should have been removed.")
			self._maid[action] = nil
		else
			if action:GetScore() ~= -math.huge then
				if not self._maid[action] then
					self._maid[action] = action:PushPreferred()
				end
			else
				self._maid[action] = nil
			end
		end
	end
end

function TouchButtonScoredActionPicker.AddAction(self: TouchButtonScoredActionPicker, action)
	if self._actionSet[action] then
		return
	end

	-- Always prefer touch buttons
	self._actionSet[action] = true

	if action:GetScore() ~= -math.huge then
		self._maid[action] = action:PushPreferred()
	end
end

function TouchButtonScoredActionPicker.RemoveAction(self: TouchButtonScoredActionPicker, action)
	self._actionSet[action] = nil
	self._maid[action] = nil
end

function TouchButtonScoredActionPicker.HasActions(self: TouchButtonScoredActionPicker)
	return next(self._actionSet) ~= nil
end

return TouchButtonScoredActionPicker