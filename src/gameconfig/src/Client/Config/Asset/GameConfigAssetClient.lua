--!strict
--[=[
	@class GameConfigAssetClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetBase = require("GameConfigAssetBase")
local GameConfigTranslator = require("GameConfigTranslator")
local Rx = require("Rx")
local _ServiceBag = require("ServiceBag")
local _JSONTranslator = require("JSONTranslator")

local GameConfigAssetClient = setmetatable({}, GameConfigAssetBase)
GameConfigAssetClient.ClassName = "GameConfigAssetClient"
GameConfigAssetClient.__index = GameConfigAssetClient

export type GameConfigAssetClient = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_configTranslator: _JSONTranslator.JSONTranslator,
	},
	GameConfigAssetClient
)) & GameConfigAssetBase.GameConfigAssetBase

--[=[
	Constructs a new GameConfigAssetClient.
	@param folder Folder
	@param serviceBag ServiceBag
	@return GameConfigAssetClient
]=]
function GameConfigAssetClient.new(folder: Folder, serviceBag: _ServiceBag.ServiceBag): GameConfigAssetClient
	local self = setmetatable(GameConfigAssetBase.new(folder, serviceBag) :: any, GameConfigAssetClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._configTranslator = self._serviceBag:GetService(GameConfigTranslator)

	return self
end

function GameConfigAssetClient:_setupEntrySet(observeTranslationKey, observeTranslationValue)
	self._maid:GiveTask(Rx.combineLatestDefer({
		assetKey = self:ObserveAssetKey();
		translationKey = observeTranslationKey;
		text = observeTranslationValue;
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