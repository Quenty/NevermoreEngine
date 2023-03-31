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
	assert(type(packageAssetId) == "number", "Bad packageAssetId")

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

--[=[
	Gets the places and their name for the current game.

	@return Pages
]=]
function AssetServiceUtils.promiseGamePlaces()
	return Promise.spawn(function(resolve, reject)
		local pages
		local ok, err = pcall(function()
			pages = AssetService:GetGamePlacesAsync()
		end)

		if not ok then
			warn(err)
			return reject(err)
		end
		if not (typeof(pages) == "Instance" and pages:IsA("Pages")) then
			return reject("pages was not an table")
		end

		resolve(pages)
	end)
end

--[=[
	Details for a specific bundle item

	@interface BundleDetailsItem
	.Id number -- Item's id
	.Name string -- Item name
	.Type string -- Item Type eg: "UserOutfit" or "Asset"
	@within AssetServiceUtils
]=]

--[=[
	Details for the bundle

	@interface BundleDetails
	.Id number -- Bundle Id (passed in as an argument)
	.Name string -- Bundle name
	.Description string -- Bundle description
	.BundleType string -- Bundle Type. eg. BodyParts or `AvatarAnimation|AvatarAnimations`
	.Items { BundleDetailsItem } -- An array of ValueTable objects
	@within AssetServiceUtils
]=]

--[=[
	Gets the bundle details

	@param bundleId number
	@return BundleDetails
]=]
function AssetServiceUtils.promiseBundleDetails(bundleId)
	assert(type(bundleId) == "number", "Bad bundleId")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = AssetService:GetBundleDetailsAsync(bundleId)
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