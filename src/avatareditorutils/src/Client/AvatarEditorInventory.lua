--[=[
	@class AvatarEditorInventory
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ObservableMap = require("ObservableMap")
local Rx = require("Rx")
local PagesUtils = require("PagesUtils")
local Promise = require("Promise")

local AvatarEditorInventory = setmetatable({}, BaseObject)
AvatarEditorInventory.ClassName = "AvatarEditorInventory"
AvatarEditorInventory.__index = AvatarEditorInventory

function AvatarEditorInventory.new()
	local self = setmetatable(BaseObject.new(), AvatarEditorInventory)

	self._assetIdToAsset = self._maid:Add(ObservableMap.new())

	return self
end

function AvatarEditorInventory:PromiseProcessPages(inventoryPages: Pages)
	return Promise.spawn(function(resolve, reject)
		local pageData = inventoryPages:GetCurrentPage()
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

function AvatarEditorInventory:IsAssetIdInInventory(assetId: number): boolean
	return self._assetIdToAsset:Get(assetId) ~= nil
end

function AvatarEditorInventory:ObserveAssetIdInInventory(assetId: number)
	assert(type(assetId) == "number", "Bad assetId")

	return self._assetIdToAsset:ObserveAtKey(assetId):Pipe({
		Rx.map(function(data)
			return data ~= nil
		end)
	})
end

return AvatarEditorInventory