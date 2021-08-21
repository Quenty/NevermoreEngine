---
-- @module PermissionProviderUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local PermissionProviderConstants = require("PermissionProviderConstants")

local PermissionProviderUtils = {}

function PermissionProviderUtils.createGroupRankConfig(config)
	assert(type(config.groupId) == "number", "Bad groupId")
	assert(type(config.minCreatorRequiredRank) == "number", "Bad minCreatorRequiredRank")
	assert(type(config.minAdminRequiredRank) == "number", "Bad minAdminRequiredRank")

	return {
		type = PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE;
		groupId = config.groupId;
		minAdminRequiredRank = config.minAdminRequiredRank;
		minCreatorRequiredRank = config.minCreatorRequiredRank;
		remoteFunctionName = config.remoteFunctionName or PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME;
	}
end

function PermissionProviderUtils.createSingleUserConfig(config)
	assert(type(config.userId) == "number", "Bad userId")

	return {
		type = PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE;
		userId = config.userId;
		remoteFunctionName = config.remoteFunctionName or PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME;
	}
end

function PermissionProviderUtils.createConfigFromGame()
	if game.CreatorType == Enum.CreatorType.Group then
		return PermissionProviderUtils.createGroupRankConfig({
			groupId = game.CreatorId;
			minAdminRequiredRank = 254;
			minCreatorRequiredRank = 255;
		})
	else
		return PermissionProviderUtils.createSingleUserConfig({
			userId = game.CreatorId;
		})
	end
end

return PermissionProviderUtils