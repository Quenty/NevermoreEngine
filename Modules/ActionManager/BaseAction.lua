--- BaseAction state for Actionmanager
-- @classmod BaseAction

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal = LoadCustomLibrary("Signal")
local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local EnabledMixin = LoadCustomLibrary("EnabledMixin")

local BaseAction = {}
BaseAction.__index = BaseAction
BaseAction.ClassName = "BaseAction"

EnabledMixin:Add(BaseAction)

function BaseAction.new(Name)
	local self = setmetatable({}, BaseAction)

	self.Maid = MakeMaid()
	self:InitEnableChanged()

	self.ActivateData = nil -- Data to be fired with the Activated event
	self.Activated = Signal.new() -- :fire(ActionMaid, ActivateData)
	self.Deactivated = Signal.new() -- :fire()
	
	self.Name = Name or error("No ActionData.Name")
	
	self.IsActivatedValue = Instance.new("BoolValue")
	self.IsActivatedValue.Value = false
	
	self.Maid:GiveTask(self.IsActivatedValue.Changed:Connect(function()
		if self.IsActivatedValue.Value then
			local ActionMaid = MakeMaid()
			self.Maid.ActionMaid = ActionMaid
			self.Activated:fire(ActionMaid, unpack(self.ActivateData))
		else
			self.Maid.ActionMaid = nil
			self.Deactivated:fire()
		end
	end))
	
	self.ContextActionKey = ("%s_ContextAction"):format(tostring(self.Name))
	
	-- Prevent being activated when disabled
	self.Maid:GiveTask(self.EnabledChanged:Connect(function(IsEnabled)
		if not IsEnabled then
			self:Deactivate()
		end
		
		self:UpdateShortcuts()
	end))
	

	return self
end

function BaseAction:GetName()
	return self.Name
end

function BaseAction:UpdateShortcuts()
	if not self.ActionData then
		return
	end
	
	local Shortcuts = self.ActionData.Shortcuts
	
	if Shortcuts and #Shortcuts > 0 then
		if self:IsEnabled() then
			ContextActionService:BindAction(self.ContextActionKey, function(Name, UserInputState, InputObject)
				if UserInputState == Enum.UserInputState.Begin then
					self:ToggleActivate()
				end
			end, false, unpack(Shortcuts))
		else
			ContextActionService:UnbindAction(self.ContextActionKey)
		end
	end
end
function BaseAction:WithActionData(ActionData)
	self.ActionData = ActionData or error("No ActionData")
		
	self:UpdateShortcuts()
	
	return self
end


function BaseAction:GetFABData()
	if not self.ActionData then
		return nil
	end
	
	local FABData = self.ActionData.FABData
	
	if FABData then
		return setmetatable({
			Name = self.Name;
		}, {__index = FABData})
	else
		return nil
	end
end

function BaseAction:ToggleActivate(...)
	self.ActivateData = {...}
	
	if self:IsEnabled() then
		self.IsActivatedValue.Value = not (self.IsActivatedValue.Value)
	else
		warn("[BaseAction][ToggleActivate] - Not activating, not enabled")
		self.IsActivatedValue.Value = false
	end
end

function BaseAction:IsActive()
	return self.IsActivatedValue.Value
end


function BaseAction:Deactivate()
	self.IsActivatedValue.Value = false
end

function BaseAction:Activate(...)
	self.ActivateData = {...}
	
	if self:IsEnabled() then
		self.IsActivatedValue.Value = true
	else
		warn("[BaseAction][Activate] - Not activating, not enabled")
	end
end

function BaseAction:Destroy()
	self.Maid:DoCleaning()

	setmetatable(self, nil)
end

return BaseAction