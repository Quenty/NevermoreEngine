--[=[
	@class PermissionLevelUtils
]=]

local require = require(script.Parent.loader).load(script)

local PermissionLevel = require("PermissionLevel")

local PermissionLevelUtils = {}

local ALLOWED = {}
for _, item in PermissionLevel do
	ALLOWED[item] = true
end

function PermissionLevelUtils.isPermissionLevel(permissionLevel)
	return ALLOWED[permissionLevel]
end

return PermissionLevelUtils