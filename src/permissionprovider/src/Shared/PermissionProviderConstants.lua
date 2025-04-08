--[=[
	Constants for the permission system
	@class PermissionProviderConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type PermissionProviderConstants = {
	DEFAULT_REMOTE_FUNCTION_NAME: "PermissionProviderDefaultRemoteFunction",
	GROUP_RANK_CONFIG_TYPE: "GroupRankConfigType",
	SINGLE_USER_CONFIG_TYPE: "SingleUserConfigType",
}

return Table.readonly({
	DEFAULT_REMOTE_FUNCTION_NAME = "PermissionProviderDefaultRemoteFunction",

	-- types
	GROUP_RANK_CONFIG_TYPE = "GroupRankConfigType",
	SINGLE_USER_CONFIG_TYPE = "SingleUserConfigType",
} :: PermissionProviderConstants)
