---
-- @module AssetServiceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AssetService = game:GetService("AssetService")

local Promise = require("Promise")

local AssetServiceUtils = {}

function AssetServiceUtils.promiseAssetIdsForPackage(packageAssetId)
	return Promise.defer(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = AssetService:GetAssetIdsForPackage(packageAssetId)
		end)

		if not ok then
			warn(err)
			return reject(err)
		end
		if typeof(result) ~= "table" then
			return reject("Result was not an table")
		end

		resolve(result)
	end)
end

return AssetServiceUtils