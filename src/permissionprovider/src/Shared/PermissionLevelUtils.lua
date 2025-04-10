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

--[=[
	Returns true if a permission level
]=]
function PermissionLevelUtils.isPermissionLevel(permissionLevel: any): boolean
	return ALLOWED[permissionLevel] == true
end

return PermissionLevelUtils