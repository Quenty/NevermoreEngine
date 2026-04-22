--!strict
--[=[
	@class GameConfigAsset
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetBase = require("GameConfigAssetBase")
local GameConfigTranslator = require("GameConfigTranslator")
local JSONTranslator = require("JSONTranslator")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")

local GameConfigAsset = setmetatable({}, GameConfigAssetBase)
GameConfigAsset.ClassName = "GameConfigAsset"
GameConfigAsset.__index = GameConfigAsset

export type GameConfigAsset =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_translator: JSONTranslator.JSONTranslator,
		},
		{} :: typeof({ __index = GameConfigAsset })
	))
	& GameConfigAssetBase.GameConfigAssetBase

function GameConfigAsset.new(obj: Folder, serviceBag: ServiceBag.ServiceBag): GameConfigAsset
	local self: GameConfigAsset = setmetatable(GameConfigAssetBase.new(obj, serviceBag) :: any, GameConfigAsset)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._translator = self._serviceBag:GetService(GameConfigTranslator)

	self._maid:GiveTask(Rx.combineLatest({
		assetKey = self:ObserveAssetKey(),
		assetType = self:ObserveAssetType(),
		text = self:ObserveCloudName(),
	}):Subscribe(function(state)
		if state.text and state.text ~= "" then
			local prefix = string.format("assets.%s.%s.name", state.assetType, state.assetKey)
			self:SetNameTranslationKey(self._translator:ToTranslationKey(prefix, state.text))
		else
			self:SetNameTranslationKey(nil)
		end
	end))

	self._maid:GiveTask(Rx.combineLatest({
		assetKey = self:ObserveAssetKey(),
		assetType = self:ObserveAssetType(),
		text = self:ObserveCloudDescription(),
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
