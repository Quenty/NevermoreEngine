---
-- @function optional
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

--[[
Sets up require.optional("Name").

Errors are still preserved because Roblox reports errors of module scripts regardless of caller
execution context.
]]

return function(_module)
	assert(type(_module) == "string"
		or type(_module) == "number"
		or (typeof(_module) == "Instance" and _module:IsA("ModuleScript")),
		"Bad module identifier")

	local result
	local ok, _ = pcall(function()
		result = require(_module)
	end)

	if not ok then
		return nil
	end

	return result
end