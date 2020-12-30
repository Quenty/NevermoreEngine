---
-- @module PermissionProviderUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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

return PermissionProviderUtils