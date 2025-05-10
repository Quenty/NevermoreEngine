--!strict
--[=[
	@class AvatarEditorInventory
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local PagesUtils = require("PagesUtils")
local Promise = require("Promise")
local Rx = require("Rx")

local AvatarEditorInventory = setmetatable({}, BaseObject)
AvatarEditorInventory.ClassName = "AvatarEditorInventory"
AvatarEditorInventory.__index = AvatarEditorInventory

export type AssetData = unknown

export type AvatarEditorInventory = typeof(setmetatable(
	{} :: {
		_assetIdToAsset: ObservableMap.ObservableMap<number, AssetData>,
	},
	{} :: typeof({ __index = AvatarEditorInventory })
)) & BaseObject.BaseObject

--[=[
	Constructs a new AvatarEditorInventory

	@return AvatarEditorInventory
]=]
function AvatarEditorInventory.new(): AvatarEditorInventory
	local self: AvatarEditorInventory = setmetatable(BaseObject.new() :: any, AvatarEditorInventory)

	self._assetIdToAsset = self._maid:Add(ObservableMap.new())

	return self
end

--[=[
	Processes the pages and stores the asset data in the inventory.
	@param inventoryPages Pages
	@return Promise.Promise<()>
]=]
function AvatarEditorInventory.PromiseProcessPages(
	self: AvatarEditorInventory,
	inventoryPages: Pages
): Promise.Promise<()>
	return Promise.spawn(function(resolve, reject)
		local pageData: any = inventoryPages:GetCurrentPage()
		while pageData do
			for _, data in pageData do
				self._assetIdToAsset:Set(data.AssetId, data)
			end

			pageData = nil

			if not inventoryPages.IsFinished then
				local ok, err = PagesUtils.promiseAdvanceToNextPage(inventoryPages):Yield()
				if not ok then
					return reject(string.format("Failed to advance to next page due to %s", tostring(err)))
				end

				pageData = err
			end
		end

		return resolve()
	end)
end

--[=[
	Returns the asset data for the given assetId.
	@param assetId number
	@return boolean
]=]
function AvatarEditorInventory.IsAssetIdInInventory(self: AvatarEditorInventory, assetId: number): boolean
	return self._assetIdToAsset:Get(assetId) ~= nil
end

--[=[
	Observes the assetId in the inventory. Returns true if it is in the inventory.
	@param assetId number
	@return Observable<AssetData>
]=]
function AvatarEditorInventory.ObserveAssetIdInInventory(
	self: AvatarEditorInventory,
	assetId: number
): Observable.Observable<AssetData>
	assert(type(assetId) == "number", "Bad assetId")

	return self._assetIdToAsset:ObserveAtKey(assetId):Pipe({
		Rx.map(function(data)
			return data ~= nil
		end) :: any,
	}) :: any
end

return AvatarEditorInventory
