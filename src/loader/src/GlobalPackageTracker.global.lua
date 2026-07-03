--[[
    This is named .global to prevent jest from hoisting it and causing warnings about failing to find packages in the cache.
]]
local PackageTrackerProvider = require(script.Parent.Dependencies.PackageTrackerProvider)

local GLOBAL_PACKAGE_TRACKER = PackageTrackerProvider.new()
script.Destroying:Connect(function()
	GLOBAL_PACKAGE_TRACKER:Destroy()
end)

return GLOBAL_PACKAGE_TRACKER
