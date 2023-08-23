--[=[
	@class WellKnownAssetOwnershipHandler
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerAssetOwnershipUtils = require("PlayerAssetOwnershipUtils")
local ValueObject = require("ValueObject")

local WellKnownAssetOwnershipHandler = setmetatable({}, BaseObject)
WellKnownAssetOwnershipHandler.ClassName = "WellKnownAssetOwnershipHandler"
WellKnownAssetOwnershipHandler.__index = WellKnownAssetOwnershipHandler

function WellKnownAssetOwnershipHandler.new(adornee, gameConfigAsset)
	local self = setmetatable(BaseObject.new(adornee), WellKnownAssetOwnershipHandler)

	self._gameConfigAsset = assert(gameConfigAsset, "No gameConfigAsset")

	self._isOwned = ValueObject.new(false, "boolean")
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

--[=[
	Sets if the asset is owned

	@param isOwned boolean
]=]
function WellKnownAssetOwnershipHandler:SetIsOwned(isOwned)
	assert(type(isOwned) == "boolean", "Bad isOwned")

	self._isOwned.Value = isOwned
end

--[=[
	Gets if the asset is owned

	@return boolean
]=]
function WellKnownAssetOwnershipHandler:GetIsOwned()
	return self._isOwned.Value
end

--[=[
	Observes if the asset is owned

	@return Observable<boolean>
]=]
function WellKnownAssetOwnershipHandler:ObserveIsOwned()
	return self._isOwned:Observe()
end

function WellKnownAssetOwnershipHandler:_observeAttributeNamesBrio()
	return PlayerAssetOwnershipUtils.observeAttributeNamesForGameConfigAssetBrio(self._gameConfigAsset:GetAssetType(), self._gameConfigAsset)
end

return WellKnownAssetOwnershipHandler