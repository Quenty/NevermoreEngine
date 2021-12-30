--[=[
	Adds Enabled/Disabled state to class
	@class EnabledMixin
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Signal = require("Signal")

local EnabledMixin = {}

function EnabledMixin:Add(class)
	assert(class, "Bad class")
	assert(not class.Enable, "class.Enable already defined")
	assert(not class.Disable, "class.Disable already defined")
	assert(not class.SetEnabled, "class.SetEnabled already defined")
	assert(not class.IsEnabled, "class.IsEnabled already defined")
	assert(not class.InitEnabledMixin, "class.InitEnabledMixin already defined")

	-- Inject methods
	class.IsEnabled = self.IsEnabled
	class.Enable = self.Enable
	class.Disable = self.Disable
	class.SetEnabled = self.SetEnabled
	class.InitEnabledMixin = self.InitEnabledMixin
end

-- Initialize EnabledMixin
function EnabledMixin:InitEnabledMixin(maid)
	maid = maid or self._maid
	assert(maid, "Must have maid")

	self._enabledMaidReference = maid

	self._enabled = false
	self.EnabledChanged = Signal.new() -- :Fire(isEnabled, doNotAnimate, enabledMaid)
	self._enabledMaidReference:GiveTask(self.EnabledChanged)
end

function EnabledMixin:IsEnabled()
	return self._enabled
end

function EnabledMixin:Enable(doNotAnimate)
	self:SetEnabled(true, doNotAnimate)
end

function EnabledMixin:Disable(doNotAnimate)
	self:SetEnabled(false, doNotAnimate)
end

function EnabledMixin:SetEnabled(isEnabled, doNotAnimate)
	assert(type(isEnabled) == "boolean", "Bad isEnabled")

	if self._enabled ~= isEnabled then
		self._enabled = isEnabled

		local enabledMaid = Maid.new()
		self._enabledMaidReference._enabledMaid = enabledMaid

		self.EnabledChanged:Fire(isEnabled, doNotAnimate, enabledMaid)
	end
end

return EnabledMixin