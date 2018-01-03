--- Adds Enabled/Disabled state to class
-- @module EnabledMixin

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local Signal = require("Signal")

local module = {}
module.__index = module
setmetatable(module, module)

function module:Add(class)
	assert(class)
	assert(not class.Enable)
	assert(not class.Disable)
	assert(not class.SetEnabled)
	assert(not class.IsEnabled)
	assert(not class.InitEnabledMixin)

	-- Inject methods
	class.IsEnabled = self.IsEnabled
	class.Enable = self.Enable
	class.Disable = self.Disable
	class.SetEnabled = self.SetEnabled
	class.InitEnabledMixin = self.InitEnabledMixin
end

-- Initialize module
function module:InitEnabledMixin(maid)
	maid = maid or self._maid
	assert(maid, "Must have maid")

	self._enabledMaidReference = maid

	self._enabled = false
	self.EnabledChanged = Signal.new()
	self._enabledMaidReference:GiveTask(self.EnabledChanged)
end

function module:IsEnabled()
	return self._enabled
end

function module:Enable(doNotAnimate)
	self:SetEnabled(true, doNotAnimate)
end

function module:Disable(doNotAnimate)
	self:SetEnabled(false, doNotAnimate)
end

function module:SetEnabled(isEnabled, doNotAnimate)
	assert(type(isEnabled) == "boolean")
	
	if self._enabled ~= isEnabled then
		self._enabled = isEnabled
		
		local enabledMaid = Maid.new()
		self._enabledMaidReference._enabledMaid = enabledMaid
		
		self.EnabledChanged:Fire(isEnabled, enabledMaid)
	end
end

return module
