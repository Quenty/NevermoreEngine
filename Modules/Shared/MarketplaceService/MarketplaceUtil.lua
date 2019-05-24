--- Provides utility methods for MarketplaceService
-- @module MarketplaceUtil

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MarketplaceService = game:GetService("MarketplaceService")

local Promise = require("Promise")

local MarketplaceUtil = {}

function MarketplaceUtil.PromisePlayerOwnsAsset(player, assetId)
	assert(typeof(player) == "Instance")
	assert(type(assetId) == "number")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = MarketplaceService:PlayerOwnsAsset(player, assetId)
		end)
		if not ok then
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Bad result type")
		end
		return resolve(result)
	end)
end

function MarketplaceUtil.PromiseUserOwnsGamePass(player, gamePassId)
	assert(typeof(player) == "Instance")
	assert(type(gamePassId) == "number")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = MarketplaceService:UserOwnsGamePassAsync(player, gamePassId)
		end)
		if not ok then
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Bad result type")
		end
		return resolve(result)
	end)
end

return MarketplaceUtil
