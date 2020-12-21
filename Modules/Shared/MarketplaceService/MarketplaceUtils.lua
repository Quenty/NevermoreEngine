--- Provides utility methods for MarketplaceService
-- @module MarketplaceUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MarketplaceService = game:GetService("MarketplaceService")

local Promise = require("Promise")

local MarketplaceUtils = {}

function MarketplaceUtils.promiseProductInfo(assetId, infoType)
	assert(type(assetId) == "number")
	assert(typeof(infoType) == "EnumItem")

	return Promise.spawn(function(resolve, reject)
		-- We hope this caches
		local productInfo
		local ok, err = pcall(function()
			productInfo = MarketplaceService:GetProductInfo(assetId, infoType)
		end)
		if not ok then
			return reject(err)
		end
		if type(productInfo) ~= "table" then
			return reject("Bad productInfo type")
		end
		return resolve(productInfo)
	end)
end

function MarketplaceUtils.promiseUserOwnsGamePass(userId, gamePassId)
	assert(typeof(userId) == "number")
	assert(type(gamePassId) == "number")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
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

-- Such as a hat or some other item!
function MarketplaceUtils.promisePlayerOwnsAsset(player, assetId)
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


return MarketplaceUtils
