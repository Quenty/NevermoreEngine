--[=[
	@class WellKnownAssetOwnershipHandler
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerAssetOwnershipUtils = require("PlayerAssetOwnershipUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local WellKnownAssetOwnershipHandler = setmetatable({}, BaseObject)
WellKnownAssetOwnershipHandler.ClassName = "WellKnownAssetOwnershipHandler"
WellKnownAssetOwnershipHandler.__index = WellKnownAssetOwnershipHandler

function WellKnownAssetOwnershipHandler.new(adornee, gameConfigAsset)
	local self = setmetatable(BaseObject.new(adornee), WellKnownAssetOwnershipHandler)

	self._gameConfigAsset = assert(gameConfigAsset, "No gameConfigAsset")

	self._isOwned = Instance.new("BoolValue")
	self._isOwned.Value = false
	self._maid:GiveTask(self._isOwned)

	self._maid:GiveTask(self:_observeAttributeNamesBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local attributeName = brio:GetValue()

		maid:GiveTask(self._isOwned.Changed:Connect(function()
			self._obj:SetAttribute(attributeName, self._isOwned.Value)
		end))

		-- preload the data
		if self._obj:GetAttribute(attributeName) == nil then
			self._obj:SetAttribute(attributeName, self._isOwned.Value)
		end

		-- Sync it up if something explicit happens
		maid:GiveTask(self._obj:GetAttributeChangedSignal(attributeName):Connect(function()
			self:SetIsOwned(self._obj:GetAttribute(attributeName) and true or false)
		end))
	end))

	return self
end

function WellKnownAssetOwnershipHandler:SetIsOwned(isOwned)
	self._isOwned.Value = isOwned
end

function WellKnownAssetOwnershipHandler:GetIsOwned()
	return self._isOwned.Value
end

function WellKnownAssetOwnershipHandler:ObserveIsOwned()
	return RxInstanceUtils.observeProperty(self._isOwned, "Value")
end

function WellKnownAssetOwnershipHandler:_observeAttributeNamesBrio()
	return PlayerAssetOwnershipUtils.observeAttributeNamesForGameConfigAssetBrio(self._gameConfigAsset:GetAssetType(), self._gameConfigAsset)
end

return WellKnownAssetOwnershipHandler