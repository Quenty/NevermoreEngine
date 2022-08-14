--[=[
	@class GameConfigAssetClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetBase = require("GameConfigAssetBase")
local GameConfigTranslator = require("GameConfigTranslator")
local Rx = require("Rx")
local PseudoLocalize = require("PseudoLocalize")

local GameConfigAssetClient = setmetatable({}, GameConfigAssetBase)
GameConfigAssetClient.ClassName = "GameConfigAssetClient"
GameConfigAssetClient.__index = GameConfigAssetClient

--[=[
	Constructs a new GameConfigAssetClient.
	@param obj Instance
	@param serviceBag ServiceBag
	@return GameConfigAssetClient
]=]
function GameConfigAssetClient.new(obj, serviceBag)
	local self = setmetatable(GameConfigAssetBase.new(obj), GameConfigAssetClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._configTranslator = self._serviceBag:GetService(GameConfigTranslator)

	self._maid:GiveTask(self:ObserveTranslatedName():Subscribe())
	self._maid:GiveTask(self:ObserveTranslatedDescription():Subscribe())

	return self
end

--[=[
	Observes the translated name
	@return Observable<string>
]=]
function GameConfigAssetClient:ObserveTranslatedName()
	-- TODO: Multicast

	return Rx.combineLatest({
		assetKey = self:ObserveAssetKey();
		translationKey = self:ObserveNameTranslationKey();
		text = self:ObserveCloudName();
	}):Pipe({
		Rx.throttleDefer();
		Rx.switchMap(function(state)
			if type(state.translationKey) == "string" and state.text and state.assetKey then
				-- Immediately write if necessary

				local localizationTable = self._configTranslator:GetLocalizationTable()
				local key = state.translationKey
				local source = state.text
				local context = ("GameConfigAsset.%s"):format(state.assetKey)
				local localeId = "en"
				local value = state.text

				localizationTable:SetEntryValue(key, source, context, localeId, value)
				localizationTable:SetEntryValue(key, source, context,
					PseudoLocalize.getDefaultPseudoLocaleId(),
					PseudoLocalize.pseudoLocalize(value))

				return self._configTranslator:ObserveFormatByKey(state.translationKey)
			else
				return Rx.EMPTY -- just don't emit anything until we have it.
			end
		end)
	})
end

--[=[
	Observes the translated description
	@return Observable<string>
]=]
function GameConfigAssetClient:ObserveTranslatedDescription()
	-- TODO: Multicast

	return Rx.combineLatest({
		assetKey = self:ObserveAssetKey();
		translationKey = self:ObserveDescriptionTranslationKey();
		text = self:ObserveCloudDescription();
	}):Pipe({
		Rx.throttleDefer();
		Rx.switchMap(function(state)
			if type(state.translationKey) == "string" and state.text and state.assetKey then
				-- Immediately write if necessary

				local localizationTable = self._configTranslator:GetLocalizationTable()
				local key = state.translationKey
				local source = state.text
				local context = ("GameConfigAsset.%s"):format(state.assetKey)
				local localeId = "en"
				local value = state.text

				localizationTable:SetEntryValue(key, source, context, localeId, value)
				localizationTable:SetEntryValue(key, source, context,
					PseudoLocalize.getDefaultPseudoLocaleId(),
					PseudoLocalize.pseudoLocalize(value))

				return self._configTranslator:ObserveFormatByKey(state.translationKey)
			else
				return Rx.EMPTY -- just don't emit anything until we have it.
			end
		end)
	})
end

return GameConfigAssetClient