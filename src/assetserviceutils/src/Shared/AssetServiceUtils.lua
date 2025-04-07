--!strict
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
	@return Promise<{ number }>
]=]
function AssetServiceUtils.promiseAssetIdsForPackage(packageAssetId: number): Promise.Promise<{ number }>
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

		return resolve(result)
	end)
end

--[=[
	Gets the places and their name for the current game.

	@return Promise<Pages>
]=]
function AssetServiceUtils.promiseGamePlaces(): Promise.Promise<Pages>
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

		return resolve(pages)
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
export type BundleDetailsItem = {
	Id: number,
	Name: string,
	Type: string,
}

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
export type BundleDetails = {
	Id: number,
	Name: string,
	Description: string,
	BundleType: string,
	Items: { BundleDetailsItem },
}

--[=[
	Gets the bundle details

	@param bundleId number
	@return Promise<BundleDetails>
]=]
function AssetServiceUtils.promiseBundleDetails(bundleId: number): Promise.Promise<BundleDetails>
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

		return resolve(result)
	end)
end

return AssetServiceUtils