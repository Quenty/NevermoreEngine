--- BaseAction state for Actionmanager
-- @classmod BaseAction

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ContextActionService = game:GetService("ContextActionService")

local Signal = require("Signal")
local Maid = require("Maid")
local EnabledMixin = require("EnabledMixin")

local BaseAction = {}
BaseAction.__index = BaseAction
BaseAction.ClassName = "BaseAction"

EnabledMixin:Add(BaseAction)

function BaseAction.new(actionData)
	assert(type(actionData) == "table")

	local self = setmetatable({}, BaseAction)

	self._maid = Maid.new()
	self._name = actionData.Name or error("No name")
	self._contextActionKey = ("%s_ContextAction"):format(tostring(self._name))
	self._activateData = nil -- Data to be fired with the Activated event

	self.Activated = Signal.new() -- :Fire(actionMaid, ... (activateData))
	self._maid:GiveTask(self.Activated)

	self.Deactivated = Signal.new() -- :Fire()
	self._maid:GiveTask(self.Deactivated)

	self.IsActivatedValue = Instance.new("BoolValue")
	self.IsActivatedValue.Value = false
	self._maid:GiveTask(self.IsActivatedValue)

	self:InitEnabledMixin()

	self._maid:GiveTask(self.IsActivatedValue.Changed:Connect(function()
		self:_handleIsActiveValueChanged()
	end))

	-- Prevent being activated when disabled
	self._maid:GiveTask(self.EnabledChanged:Connect(function(isEnabled)
		self:_handleEnabledChanged(isEnabled)
	end))

	self:_withActionData(actionData)


	return self
end

function BaseAction:_handleEnabledChanged(isEnabled)
	if not isEnabled then
		self:Deactivate()
	end

	self:_updateShortcuts()
end

function BaseAction:_handleIsActiveValueChanged()
	if self.IsActivatedValue.Value then
		local actionMaid = Maid.new()
		self._maid._actionMaid = actionMaid
		self.Activated:Fire(actionMaid, unpack(self._activateData))
		self._activateData = nil
	else
		self._maid._actionMaid = nil
		self.Deactivated:Fire()
	end
end

function BaseAction:GetName()
	return self._name
end

function BaseAction:_withActionData(actionData)
	self._actionData = actionData or error("No actionData")

	self:_updateShortcuts()

	return self
end

function BaseAction:_updateShortcuts()
	if not self._actionData then
		return
	end

	local shortcuts = self._actionData.Shortcuts
	if not (shortcuts and #shortcuts > 0) then
		return
	end

	if self:IsEnabled() then
		ContextActionService:BindAction(self._contextActionKey, function(actionName, userInputState, inputObject)
			if userInputState == Enum.UserInputState.Begin then
				if self._actionData.CanActivateShortcutCallback then
					if not self._actionData.CanActivateShortcutCallback() then
						return
					end
				end

				self:ToggleActivate()
			end
		end, false, unpack(shortcuts))
	else
		ContextActionService:UnbindAction(self._contextActionKey)
	end
end

function BaseAction:GetData()
	return self._actionData
end

function BaseAction:ToggleActivate(...)
	self._activateData = {...}

	if self:IsEnabled() then
		self.IsActivatedValue.Value = not (self.IsActivatedValue.Value)
	else
		warn("[BaseAction.ToggleActivate] - Not activating, not enabled")
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
		warn(("[%s.Activate] - Not activating. Disabled!"):format(self:GetName()))
	end
end

function BaseAction:Destroy()
	self._maid:DoCleaning()

	setmetatable(self, nil)
end

return BaseAction