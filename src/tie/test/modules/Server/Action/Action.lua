--[[
	@class Action
]]

local require = require(script.Parent.loader).load(script)

local ActionInterface = require("ActionInterface")
local BaseObject = require("BaseObject")
local Signal = require("Signal")

local Action = setmetatable({}, BaseObject)
Action.ClassName = "Action"
Action.__index = Action

function Action.new(obj)
	local self = setmetatable(BaseObject.new(obj), Action)

	self.Activated = self._maid:Add(Signal.new())

	self.DisplayName = self._maid:Add(Instance.new("StringValue"))
	self.DisplayName.Value = "Action"

	self.IsEnabled = self._maid:Add(Instance.new("BoolValue"))
	self.IsEnabled.Value = false

	self._maid:GiveTask(ActionInterface.Server:Implement(self._obj, self))

	return self
end

function Action:Activate()
	self.Activated:Fire()
end

return Action
