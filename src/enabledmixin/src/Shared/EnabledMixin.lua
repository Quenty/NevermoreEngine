--[=[
	Adds Enabled/Disabled state to class
	@class EnabledMixin
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local ValueObject = require("ValueObject")
local _Observable = require("Observable")
local _Maid = require("Maid")

local EnabledMixin = {}

function EnabledMixin:Add(class)
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
function EnabledMixin:InitEnabledMixin(maid: _Maid.Maid?)
	maid = maid or self._maid
	assert(maid, "Must have maid")

	self._enabledMaidReference = maid

	self._enabledState = maid:Add(ValueObject.new(false, "boolean"))

	self.EnabledChanged = maid:Add(Signal.new()) -- :Fire(isEnabled, doNotAnimate)

	self._maid:GiveTask(self._enabledState.Changed:Connect(function(isEnabled, _, doNotAnimate)
		self.EnabledChanged:Fire(isEnabled, doNotAnimate)
	end))
end

function EnabledMixin:IsEnabled(): boolean
	return self._enabledState.Value
end

function EnabledMixin:Enable(doNotAnimate: boolean?)
	self:SetEnabled(true, doNotAnimate)
end

function EnabledMixin:Disable(doNotAnimate: boolean?)
	self:SetEnabled(false, doNotAnimate)
end

function EnabledMixin:ObserveIsEnabled(): _Observable.Observable<boolean>
	return self._enabledState:Observe()
end

function EnabledMixin:SetEnabled(isEnabled: boolean, doNotAnimate: boolean?)
	assert(type(isEnabled) == "boolean", "Bad isEnabled")

	self._enabledState:SetValue(isEnabled, doNotAnimate)
end

return EnabledMixin