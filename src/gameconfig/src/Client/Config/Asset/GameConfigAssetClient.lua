--[=[
	@class GameConfigAssetClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetBase = require("GameConfigAssetBase")
local GameConfigTranslator = require("GameConfigTranslator")
local Rx = require("Rx")

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
	local self = setmetatable(GameConfigAssetBase.new(obj, serviceBag), GameConfigAssetClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._configTranslator = self._serviceBag:GetService(GameConfigTranslator)

	return self
end

function GameConfigAssetClient:_setupEntrySet(observeTranslationKey, observeTranslationValue)
	self._maid:GiveTask(Rx.combineLatest({
		assetKey = self:ObserveAssetKey();
		translationKey = observeTranslationKey;
		text = observeTranslationValue;
	}):Pipe({
		Rx.throttleDefer();
	}):Subscribe(function(state)
			if type(state.translationKey) == "string"
				and type(state.text) == "string"
				and #state.text > 0
				and state.assetKey then

				local context = string.format("GameConfigAsset.%s", state.assetKey)
				local localeId = "en"

				self._configTranslator:SetEntryValue(state.translationKey, state.text, context, localeId, state.text)
			end
	end))
end

return GameConfigAssetClient