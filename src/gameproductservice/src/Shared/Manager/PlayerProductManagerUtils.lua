--[=[
	@class PlayerProductManagerUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerProductManagerUtils = {}

function PlayerProductManagerUtils.toOwnedAttribute(assetKey)
	assert(type(assetKey) == "string", "bad assetKey")

	return ("OwnsPass_%s"):format(assetKey)
end

function PlayerProductManagerUtils.toIdOwnedAttribute(gamePassId)
	return ("OwnsPass_Id%d"):format(gamePassId)
end

return PlayerProductManagerUtils