local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local BasicPane = LoadCustomLibrary("BasicPane")
local BaseAction = LoadCustomLibrary("BaseAction")
local ValueObject = LoadCustomLibrary("ValueObject")
local Signal = LoadCustomLibrary("Signal")

-- Intent: 
-- @author Quenty

local ActionManager = setmetatable({}, BasicPane)
ActionManager.__index = ActionManager
ActionManager.ClassName = "ActionManager"

function ActionManager.new()
	local self = setmetatable(BasicPane.new(nil, {BasicPane.EnabledModule}), ActionManager)
	
	self.ActiveAction = ValueObject.new()
	self.Actions = {}
	
	self.ActionAdded = Signal.new() -- :fire(Action)
	
	self.Maid.ToolEquipped = ContextActionService.LocalToolEquipped:Connect(function(Tool)
		self:StopCurrentAction()
	end)
	
	self.Maid:GiveTask(self.EnabledChanged:Connect(function(IsEnabled)
		self:StopCurrentAction()
		
		for _, Action in pairs(self.Actions) do
			Action:SetEnabled(IsEnabled)
		end
	end))
	
	self.Maid:GiveTask(self.ActiveAction.Changed:Connect(function(Value, OldValue)
		local Maid = MakeMaid()
		if Value then
			Maid:GiveTask(function()
				Value:Deactivate()
			end)
			Maid:GiveTask(Value.Deactivated:Connect(function()
				if self.ActiveAction == Value then
					self.ActiveAction.Value = nil
				end
			end))
		end
		self.Maid.ActiveActionMaid = Maid
		
		-- Immediately deactivate
		if Value and not Value.IsActivatedValue.Value then
			warn("Immediate deactiation")
			self.ActiveAction.Value = nil
		end
	end))
	
	return self
end

function ActionManager:StopCurrentAction()
	self.ActiveAction.Value = nil
end

function ActionManager:ActivateAction(Name, ...)
	local Action = self:GetAction(Name)
	if Action then
		Action:Activate(...)
	else
		error(("[ActionManager] - No action with name '%s'"):format(tostring(Name)))
	end
end

function ActionManager:GetAction(Name)
	return self.Actions[Name]
end

function ActionManager:CreateAction(Name, ActionData)
	local Action = BaseAction.new(Name)
	
	if ActionData then
		Action:WithActionData(ActionData)
	end
	
	self:AddAction(Action)
	
	return Action
end

function ActionManager:GetActions()
	local Actions = {}
	
	for _, Action in pairs(self.Actions) do
		table.insert(Actions, Action)
	end
	
	return Actions
end

function ActionManager:AddAction(Action)
	local Name = Action:GetName()
	
	if self.Actions[Name] then
		error(("[ActionManager] - Action with name '%s' already exists"):format(tostring(Name)))
		return
	end
	
	self.Actions[Name] = Action
	
	Action:SetEnabled(self:IsEnabled())
	
	self.Maid:GiveTask(Action.Activated:Connect(function()
		self.ActiveAction.Value = Action
	end))
	
	self.Maid:GiveTask(Action.Deactivated:Connect(function()
		if self.ActiveAction.Value == Action then
			self.ActiveAction.Value = nil
		end
	end))
	
	self.ActionAdded:fire(Action)
	
	return self
end

return ActionManager