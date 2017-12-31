--- BaseAction state for Actionmanager
-- @classmod BaseAction

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local ContextActionService = game:GetService("ContextActionService")

local Signal = require("Signal")
local Maid = require("Maid")
local EnabledMixin = require("EnabledMixin")

local BaseAction = {}
BaseAction.__index = BaseAction
BaseAction.ClassName = "BaseAction"

EnabledMixin:Add(BaseAction)

function BaseAction.new(Name)
	local self = setmetatable({}, BaseAction)

	self._maid = Maid.new()
	self._name = Name or error("No ActionData.Name")
	self._contextActionKey = ("%s_ContextAction"):format(tostring(self._name))
	self._activateData = nil -- Data to be fired with the Activated event

	self.Activated = Signal.new() -- :Fire(actionMaid, ... (activateData))
	self.Deactivated = Signal.new() -- :Fire()
	
	self.IsActivatedValue = Instance.new("BoolValue")
	self.IsActivatedValue.Value = false
	
	self:InitEnableChanged()
	
	self._maid:GiveTask(self.IsActivatedValue.Changed:Connect(function()
		if self.IsActivatedValue.Value then
			local actionMaid = Maid.new()
			self._maid._actionMaid = actionMaid
			self.Activated:Fire(actionMaid, unpack(self._activateData))
		else
			self._maid._actionMaid = nil
			self.Deactivated:Fire()
		end
	end))
	
	-- Prevent being activated when disabled
	self._maid:GiveTask(self.EnabledChanged:Connect(function(IsEnabled)
		if not IsEnabled then
			self:Deactivate()
		end
		
		self:_updateShortcuts()
	end))
	

	return self
end

function BaseAction:GetName()
	return self._name
end

function BaseAction:WithActionData(actionData)
	self._actionData = actionData or error("No actionData")
		
	self:_updateShortcuts()
	
	return self
end

function BaseAction:_updateShortcuts()
	if not self._actionData then
		return
	end
	
	local Shortcuts = self._actionData.Shortcuts
	
	if Shortcuts and #Shortcuts > 0 then
		if self:IsEnabled() then
			ContextActionService:BindAction(self._contextActionKey, function(Name, UserInputState, InputObject)
				if UserInputState == Enum.UserInputState.Begin then
					self:ToggleActivate()
				end
			end, false, unpack(Shortcuts))
		else
			ContextActionService:UnbindAction(self._contextActionKey)
		end
	end
end

function BaseAction:GetFABData()
	if not self._actionData then
		return nil
	end
	
	local FABData = self._actionData.FABData
	
	if FABData then
		return setmetatable({
			Name = self._name;
		}, {__index = FABData})
	else
		return nil
	end
end

function BaseAction:ToggleActivate(...)
	self._activateData = {...}
	
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
	self._activateData = {...}
	
	if self:IsEnabled() then
		self.IsActivatedValue.Value = true
	else
		warn(("[%s][Activate] - Not activating. Disabled!"):format(self:GetName()))
	end
end

function BaseAction:Destroy()
	self._maid:DoCleaning()

	setmetatable(self, nil)
end

return BaseAction