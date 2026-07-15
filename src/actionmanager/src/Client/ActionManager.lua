--!strict
--[=[
	Holds single toggleable actions (like a tool system).

	:::info
	This is legacy code and probably should not be used in new games.
	:::

	@class ActionManager
]=]

local require = require(script.Parent.loader).load(script)

local ContextActionService = game:GetService("ContextActionService")

local BaseAction = require("BaseAction")
local Maid = require("Maid")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local ActionManager = {}
ActionManager.__index = ActionManager
ActionManager.ClassName = "ActionManager"

export type ActionManager = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_actions: { [string]: BaseAction.BaseAction },
		ActiveAction: ValueObject.ValueObject<BaseAction.BaseAction?>,
		ActionAdded: Signal.Signal<BaseAction.BaseAction>,
	},
	{} :: typeof({ __index = ActionManager })
))

function ActionManager.new(): ActionManager
	local self: ActionManager = setmetatable({} :: any, ActionManager)

	self._maid = Maid.new()
	self._actions = {}

	self.ActiveAction = self._maid:Add(ValueObject.new() :: ValueObject.ValueObject<BaseAction.BaseAction?>)
	self.ActionAdded = self._maid:Add(Signal.new() :: any) -- :Fire(action)

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
				if self.ActiveAction.Value == value then
					self.ActiveAction.Value = nil
				end
			end))
		end
		self._maid._activeActionMaid = maid

		-- Immediately deactivate
		if value and not value.IsActivatedValue.Value then
			warn(
				string.format(
					"[ActionManager.ActiveAction.Changed] - Immediate deactivation of %q",
					tostring(value:GetName())
				)
			)
			self.ActiveAction.Value = nil
		end
	end))

	return self
end

function ActionManager.StopCurrentAction(self: ActionManager): ()
	self.ActiveAction.Value = nil
end

function ActionManager.ActivateAction(self: ActionManager, name: string, ...): ()
	local action = self:GetAction(name)
	if action then
		action:Activate(...)
	else
		error(string.format("[ActionManager] - No action with name '%s'", tostring(name)))
	end
end

function ActionManager.GetAction(self: ActionManager, name: string): BaseAction.BaseAction?
	return self._actions[name]
end

function ActionManager.GetActions(self: ActionManager): { BaseAction.BaseAction }
	local list: { BaseAction.BaseAction } = {}

	for _, action in self._actions do
		table.insert(list, action :: any)
	end

	return list
end

function ActionManager.AddAction(self: ActionManager, action: BaseAction.BaseAction): ActionManager
	local name = action:GetName()

	if self._actions[name] then
		error(string.format("[ActionManager] - action with name '%s' already exists", tostring(name)))
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

function ActionManager.Destroy(self: ActionManager): ()
	self._maid:Destroy()
end

return ActionManager
