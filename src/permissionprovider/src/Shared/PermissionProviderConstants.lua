---
-- @module PermissionProviderConstants
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

return Table.readonly({
	DEFAULT_REMOTE_FUNCTION_NAME = "PermissionProviderDefaultRemoteFunction";

	-- types
	GROUP_RANK_CONFIG_TYPE = "GroupRankConfigType";
})