--[=[
	Holds single toggleable actions (like a tool system).

	:::info
	This is legacy code and probably should not be used in new games.
	:::

	@class ActionManager
]=]

local require = require(script.Parent.loader).load(script)

local ContextActionService = game:GetService("ContextActionService")

local ValueObject = require("ValueObject")
local Signal = require("Signal")
local Maid = require("Maid")

local ActionManager = setmetatable({}, {})
ActionManager.__index = ActionManager
ActionManager.ClassName = "ActionManager"

function ActionManager.new()
	local self = setmetatable({}, ActionManager)

	self._maid = Maid.new()
	self._actions = {}

	self.ActiveAction = self._maid:Add(ValueObject.new())
	self.ActionAdded = self._maid:Add(Signal.new()) -- :Fire(action)

	-- Stop actions while tool is in play
	self._maid.ToolEquipped = ContextActionService.LocalToolEquipped:Connect(function(_)
		self:StopCurrentAction()
	end)

	self._maid:GiveTask(self.ActiveAction.Changed:Connect(function(value, _)
		local maid = Maid.new()
		if value then
			maid:GiveTask(function()
				value:Deactivate()
			end)
			maid:GiveTask(value.Deactivated:Connect(function()
				if self.ActiveAction == value then
					self.ActiveAction.Value = nil
				end
			end))
		end
		self._maid._activeActionMaid = maid

		-- Immediately deactivate
		if value and not value.IsActivatedValue.Value then
			warn(string.format("[ActionManager.ActiveAction.Changed] - Immediate deactivation of %q", tostring(value:GetName())))
			self.ActiveAction.Value = nil
		end
	end))

	return self
end

function ActionManager:StopCurrentAction()
	self.ActiveAction.Value = nil
end

function ActionManager:ActivateAction(name, ...)
	local action = self:GetAction(name)
	if action then
		action:Activate(...)
	else
		error(string.format("[ActionManager] - No action with name '%s'", tostring(name)))
	end
end

function ActionManager:GetAction(name)
	return self._actions[name]
end

function ActionManager:GetActions()
	local list = {}

	for _, action in self._actions do
		table.insert(list, action)
	end

	return list
end

function ActionManager:AddAction(action)
	local name = action:GetName()

	if self._actions[name] then
		error(string.format("[ActionManager] - action with name '%s' already exists", tostring(name)))
		return
	end

	self._actions[name] = action

	self._maid:GiveTask(action.Activated:Connect(function()
		self.ActiveAction.Value = action
	end))

	self._maid:GiveTask(action.Deactivated:Connect(function()
		if self.ActiveAction.Value == action then
			self.ActiveAction.Value = nil
		end
	end))

	self.ActionAdded:Fire(action)

	return self
end

function ActionManager:Destroy()
	self._maid:Destroy()
end

return ActionManager
