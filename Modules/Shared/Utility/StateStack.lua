---
-- @classmod StateStack
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")

local StateStack = setmetatable({}, BaseObject)
StateStack.ClassName = "StateStack"
StateStack.__index = StateStack

function StateStack.new()
	local self = setmetatable(BaseObject.new(), StateStack)

	self._state = Instance.new("BoolValue")
	self._state.Value = false
	self._maid:GiveTask(self._state)

	self._stateStack = {}

	self.Changed = self._state.Changed -- :Fire(newState)

	return self
end

function StateStack:GetState()
	return self._state.Value
end

function StateStack:PushState()
	local data = {}
	table.insert(self._stateStack, data)

	self:_updateState()

	return function()
		if self.Destroy then
			self:_popState(data)
		end
	end
end

function StateStack:_popState(data)
	local index = table.find(self._stateStack, data)
	if index then
		table.remove(self._stateStack, index)
		self:_updateState()
	else
		warn("[StateStack] - Failed to find index")
	end
end

function StateStack:_updateState()
	self._state.Value = next(self._stateStack) ~= nil
end

return StateStack