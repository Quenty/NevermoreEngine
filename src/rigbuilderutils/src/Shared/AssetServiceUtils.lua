--[=[
	Utility methods involving the AssetService
	@class AssetServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local AssetService = game:GetService("AssetService")

local Promise = require("Promise")

local AssetServiceUtils = {}

--[=[
	Retrieves the assetIds for a package

	@param packageAssetId number
	@return Promise<table>
]=]
function AssetServiceUtils.promiseAssetIdsForPackage(packageAssetId)
	return Promise.spawn(function(resolve, reject)
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