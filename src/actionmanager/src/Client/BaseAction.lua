--!strict
--[=[
	BaseAction state for [ActionManager].

	:::info
	This is legacy code and probably should not be used in new games.
	:::

	@class BaseAction
]=]

local require = require(script.Parent.loader).load(script)

local ContextActionService = game:GetService("ContextActionService")

local EnabledMixin = require("EnabledMixin")
local Maid = require("Maid")
local Observable = require("Observable")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local BaseAction = {}
BaseAction.__index = BaseAction
BaseAction.ClassName = "BaseAction"

(EnabledMixin :: any):Add(BaseAction)

export type ActionData = {
	Name: string,
	Shortcuts: { any }?,
	[any]: any,
}

export type BaseAction = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_name: string,
		_contextActionKey: string,
		_activateData: { any }?,
		_actionData: ActionData,
		Activated: Signal.Signal<...any>,
		Deactivated: Signal.Signal<()>,
		IsActivatedValue: ValueObject.ValueObject<boolean>,

		-- EnabledMixin surface (methods injected at runtime via EnabledMixin:Add)
		_enabledMaidReference: Maid.Maid,
		_enabledState: ValueObject.ValueObject<boolean>,
		EnabledChanged: Signal.Signal<(boolean, boolean?)>,
		InitEnabledMixin: (self: any, maid: Maid.Maid?) -> (),
		IsEnabled: (self: any) -> boolean,
		Enable: (self: any, doNotAnimate: boolean?) -> (),
		Disable: (self: any, doNotAnimate: boolean?) -> (),
		SetEnabled: (self: any, isEnabled: boolean, doNotAnimate: boolean?) -> (),
		ObserveIsEnabled: (self: any) -> Observable.Observable<boolean>,
	},
	{} :: typeof({ __index = BaseAction })
))

function BaseAction.new(actionData: ActionData): BaseAction
	assert(type(actionData) == "table", "Bad actionData")

	local self: BaseAction = setmetatable({} :: any, BaseAction)

	self._maid = Maid.new()
	self._name = actionData.Name or error("No name")
	self._contextActionKey = string.format("%s_ContextAction", tostring(self._name))
	self._activateData = nil -- Data to be fired with the Activated event

	self.Activated = self._maid:Add(Signal.new() :: Signal.Signal<...any>) -- :Fire(actionMaid, ... (activateData))
	self.Deactivated = self._maid:Add(Signal.new() :: Signal.Signal<()>) -- :Fire()

	self.IsActivatedValue = self._maid:Add(ValueObject.new(false, "boolean"))

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

function BaseAction._handleEnabledChanged(self: BaseAction, isEnabled: boolean): ()
	if not isEnabled then
		self:Deactivate()
	end

	self:_updateShortcuts()
end

function BaseAction._handleIsActiveValueChanged(self: BaseAction): ()
	if self.IsActivatedValue.Value then
		local actionMaid = Maid.new()
		self._maid._actionMaid = actionMaid
		self.Activated:Fire(actionMaid, unpack(self._activateData or {}))
		self._activateData = nil
	else
		self._maid._actionMaid = nil
		self.Deactivated:Fire()
	end
end

function BaseAction.GetName(self: BaseAction): string
	return self._name
end

function BaseAction._withActionData(self: BaseAction, actionData: ActionData): BaseAction
	self._actionData = actionData or error("No actionData")

	self:_updateShortcuts()

	return self
end

function BaseAction._updateShortcuts(self: BaseAction): ()
	if not self._actionData then
		return
	end

	local shortcuts = self._actionData.Shortcuts
	if not (shortcuts and #shortcuts > 0) then
		return
	end

	if self:IsEnabled() then
		ContextActionService:BindAction(self._contextActionKey, function(_, userInputState, _)
			if userInputState == Enum.UserInputState.Begin then
				self:ToggleActivate()
			end
		end, false, unpack(shortcuts))
	else
		ContextActionService:UnbindAction(self._contextActionKey)
	end
end

function BaseAction.GetData(self: BaseAction): ActionData
	return self._actionData
end

function BaseAction.ToggleActivate(self: BaseAction, ...): ()
	self._activateData = { ... }

	if self:IsEnabled() then
		self.IsActivatedValue.Value = not self.IsActivatedValue.Value
	else
		warn("[BaseAction.ToggleActivate] - Not activating, not enabled")
		self.IsActivatedValue.Value = false
	end
end

function BaseAction.IsActive(self: BaseAction): boolean
	return self.IsActivatedValue.Value
end

function BaseAction.Deactivate(self: BaseAction): ()
	self.IsActivatedValue.Value = false
end

function BaseAction.Activate(self: BaseAction, ...): ()
	self._activateData = { ... }

	if self:IsEnabled() then
		self.IsActivatedValue.Value = true
	else
		warn(string.format("[%s.Activate] - Not activating. Disabled!", self:GetName()))
	end
end

function BaseAction.Destroy(self: BaseAction): ()
	self._maid:DoCleaning()

	setmetatable(self :: any, nil)
end

return BaseAction
