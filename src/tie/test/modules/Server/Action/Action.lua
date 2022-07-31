--[=[
	@class Action
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ActionInterface = require("ActionInterface")
local Signal = require("Signal")

local Action = setmetatable({}, BaseObject)
Action.ClassName = "Action"
Action.__index = Action

function Action.new(obj)
	local self = setmetatable(BaseObject.new(obj), Action)

	self.Activated = Signal.new()
	self._maid:GiveTask(self.Activated)

	self.DisplayName = Instance.new("StringValue")
	self.DisplayName.Value = "Action"
	self._maid:GiveTask(self.DisplayName)

	self.IsEnabled = Instance.new("BoolValue")
	self.IsEnabled.Value = false
	self._maid:GiveTask(self.IsEnabled)

	self._maid:GiveTask(ActionInterface:Implement(self._obj, self))

	return self
end

function Action:Activate()
	self.Activated:Fire()
end

return Action