local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

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
	assert(not class.InitEnableChanged)

	-- Inject methods
	class.IsEnabled = self.IsEnabled
	class.Enable = self.Enable
	class.Disable = self.Disable
	class.SetEnabled = self.SetEnabled
	class.InitEnableChanged = self.InitEnableChanged
end

-- Initialize module
function module:InitEnableChanged()
	assert(self.Maid)

	self._enabled = false
	self.EnabledChanged = Signal.new()
	self.Maid:GiveTask(self.EnabledChanged)
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
		self.Maid._enabledMaid = enabledMaid
		
		self.EnabledChanged:fire(isEnabled, enabledMaid)
		
		if self.RefreshGuiPosition then
			self:RefreshGuiPosition(doNotAnimate)
		end
	end
end

return module
