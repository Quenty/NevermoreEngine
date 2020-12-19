---
-- @module GenericPermissionProviderUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GenericPermissionProviderConstants = require("GenericPermissionProviderConstants")

local GenericPermissionProviderUtils = {}

function GenericPermissionProviderUtils.createGroupRankConfig(config)
	assert(config.groupId)
	assert(config.minRequiredRank)

	return {
		type = GenericPermissionProviderConstants.GROUP_RANK_CONFIG_TYPE;
		groupId = config.groupId;
		minRequiredRank = config.minRequiredRank;
	}
end

return GenericPermissionProviderUtils