--!strict
--[=[
	Utility functions to provide/configure a permission. See [BasePermissionProvider] and [PermissionService].

	@server
	@class PermissionProviderUtils
]=]

local require = require(script.Parent.loader).load(script)

local PermissionProviderConstants = require("PermissionProviderConstants")

local PermissionProviderUtils = {}

type GroupRankConfig_Input = {
	groupId: number,
	minAdminRequiredRank: number,
	minCreatorRequiredRank: number,
	remoteFunctionName: string?,
}

export type GroupRankConfig = {
	type: "GroupRankConfigType",
} & GroupRankConfig_Input

export type SingleUserConfig_Input = {
	userId: number,
	remoteFunctionName: string?,
}

export type SingleUserConfig = {
	type: "SingleUserConfigType",
} & SingleUserConfig_Input

export type PermissionProviderConfig = GroupRankConfig | SingleUserConfig

--[=[
	Creates a group rank config
	@param config { groupId: number, minAdminRequiredRank: number, minCreatorRequiredRank: number }
	@return table
]=]
function PermissionProviderUtils.createGroupRankConfig(config: GroupRankConfig_Input): GroupRankConfig
	assert(type(config.groupId) == "number", "Bad groupId")
	assert(type(config.minCreatorRequiredRank) == "number", "Bad minCreatorRequiredRank")
	assert(type(config.minAdminRequiredRank) == "number", "Bad minAdminRequiredRank")

	return {
		type = PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE,
		groupId = config.groupId,
		minAdminRequiredRank = config.minAdminRequiredRank,
		minCreatorRequiredRank = config.minCreatorRequiredRank,
		remoteFunctionName = config.remoteFunctionName or PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME,
	}
end

--[=[
	Creates a single user config
	@param config { userId: number }
	@return table
]=]
function PermissionProviderUtils.createSingleUserConfig(config: SingleUserConfig_Input): SingleUserConfig
	assert(type(config.userId) == "number", "Bad userId")

	return {
		type = PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE,
		userId = config.userId,
		remoteFunctionName = config.remoteFunctionName or PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME,
	}
end

--[=[
	Creates an automatic configuration from the game.
	@return table
]=]
function PermissionProviderUtils.createConfigFromGame(): PermissionProviderConfig
	if game.CreatorType == Enum.CreatorType.Group then
		return PermissionProviderUtils.createGroupRankConfig({
			groupId = game.CreatorId;
			minAdminRequiredRank = 250;
			minCreatorRequiredRank = 254;
		})
	else
		return PermissionProviderUtils.createSingleUserConfig({
			userId = game.CreatorId;
		})
	end
end

return PermissionProviderUtils