--!strict
--[=[
	Adds Enabled/Disabled state to class
	@class EnabledMixin
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local EnabledMixin = {}

export type EnabledMixin = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_enabledMaidReference: Maid.Maid,
		_enabledState: ValueObject.ValueObject<boolean>,
		EnabledChanged: Signal.Signal<(boolean, boolean?)>,
	},
	{} :: typeof({ __index = EnabledMixin })
))

function EnabledMixin.Add(self: EnabledMixin, class: any): ()
	assert(class, "Bad class")
	assert(not class.Enable, "class.Enable already defined")
	assert(not class.Disable, "class.Disable already defined")
	assert(not class.SetEnabled, "class.SetEnabled already defined")
	assert(not class.IsEnabled, "class.IsEnabled already defined")
	assert(not class.InitEnabledMixin, "class.InitEnabledMixin already defined")
	assert(not class.ObserveIsEnabled, "class.ObserveIsEnabled already defined")

	-- Inject methods
	class.IsEnabled = self.IsEnabled
	class.Enable = self.Enable
	class.Disable = self.Disable
	class.SetEnabled = self.SetEnabled
	class.ObserveIsEnabled = self.ObserveIsEnabled
	class.InitEnabledMixin = self.InitEnabledMixin
end

-- Initialize EnabledMixin
function EnabledMixin.InitEnabledMixin(self: EnabledMixin, maid: Maid.Maid?): ()
	local resolvedMaid: Maid.Maid = (maid or self._maid) :: any
	assert(resolvedMaid, "Must have maid")

	self._enabledMaidReference = resolvedMaid

	self._enabledState = (resolvedMaid :: any):Add(ValueObject.new(false, "boolean"))

	self.EnabledChanged = (resolvedMaid :: any):Add(Signal.new()) -- :Fire(isEnabled, doNotAnimate)

	self._maid:GiveTask((self._enabledState :: any).Changed:Connect(function(isEnabled, _, doNotAnimate)
		self.EnabledChanged:Fire(isEnabled, doNotAnimate)
	end))
end

function EnabledMixin.IsEnabled(self: EnabledMixin): boolean
	return self._enabledState.Value
end

function EnabledMixin.Enable(self: EnabledMixin, doNotAnimate: boolean?): ()
	self:SetEnabled(true, doNotAnimate)
end

function EnabledMixin.Disable(self: EnabledMixin, doNotAnimate: boolean?): ()
	self:SetEnabled(false, doNotAnimate)
end

function EnabledMixin.ObserveIsEnabled(self: EnabledMixin): Observable.Observable<boolean>
	return self._enabledState:Observe()
end

function EnabledMixin.SetEnabled(self: EnabledMixin, isEnabled: boolean, doNotAnimate: boolean?): ()
	assert(type(isEnabled) == "boolean", "Bad isEnabled")

	self._enabledState:SetValue(isEnabled, doNotAnimate)
end

return EnabledMixin
