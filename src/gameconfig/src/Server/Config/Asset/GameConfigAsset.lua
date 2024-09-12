--[=[
	@class GameConfigAsset
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetBase = require("GameConfigAssetBase")
local GameConfigTranslator = require("GameConfigTranslator")
local Rx = require("Rx")

local GameConfigAsset = setmetatable({}, GameConfigAssetBase)
GameConfigAsset.ClassName = "GameConfigAsset"
GameConfigAsset.__index = GameConfigAsset

function GameConfigAsset.new(obj, serviceBag)
	local self = setmetatable(GameConfigAssetBase.new(obj, serviceBag), GameConfigAsset)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._translator = self._serviceBag:GetService(GameConfigTranslator)

	self._maid:GiveTask(Rx.combineLatest({
		assetKey = self:ObserveAssetKey();
		assetType = self:ObserveAssetType();
		text = self:ObserveCloudName();
	}):Subscribe(function(state)
		if state.text and state.text ~= "" then
			local prefix = string.format("assets.%s.%s.name", state.assetType, state.assetKey)
			self:SetNameTranslationKey(self._translator:ToTranslationKey(prefix, state.text))
		else
			self:SetNameTranslationKey(nil)
		end
	end))

	self._maid:GiveTask(Rx.combineLatest({
		assetKey = self:ObserveAssetKey();
		assetType = self:ObserveAssetType();
		text = self:ObserveCloudDescription();
	}):Subscribe(function(state)
		if state.text and state.text ~= "" then
			local prefix = string.format("assets.%s.%s.description", state.assetType, state.assetKey)
			self:SetDescriptionTranslationKey(self._translator:ToTranslationKey(prefix, state.text))
		else
			self:SetDescriptionTranslationKey(nil)
		end
	end))

	return self
end

return GameConfigAsset