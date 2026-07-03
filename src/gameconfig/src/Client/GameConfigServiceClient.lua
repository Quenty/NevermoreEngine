--!strict
--[=[
	@class GameConfigServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigPicker = require("GameConfigPicker")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local GameConfigServiceClient = {}
GameConfigServiceClient.ServiceName = "GameConfigServiceClient"

export type GameConfigServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_binders: any,
		_configPicker: GameConfigPicker.GameConfigPicker,
	},
	{} :: typeof({ __index = GameConfigServiceClient })
))

function GameConfigServiceClient.Init(self: GameConfigServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))
	self._serviceBag:GetService(require("MarketplaceServiceCache"))

	-- Internal
	self._serviceBag:GetService((require :: any)("GameConfigCommandServiceClient"))
	self._serviceBag:GetService(require("GameConfigTranslator"))
	self._serviceBag:GetService(require("GameConfigDataService"))
	self._binders = self._serviceBag:GetService(require("GameConfigBindersClient"))

	self._configPicker =
		self._maid:Add(GameConfigPicker.new(self._serviceBag, self._binders.GameConfig, self._binders.GameConfigAsset))

	local dataService = self._serviceBag:GetService(require("GameConfigDataService"));
	(dataService :: any):SetConfigPicker(self._configPicker)
end

function GameConfigServiceClient.Start(self: GameConfigServiceClient): () end

--[=[
	Retrieves the game configuration picker for the config service.
	@return GameConfigPicker
]=]
function GameConfigServiceClient.GetConfigPicker(self: GameConfigServiceClient): GameConfigPicker.GameConfigPicker
	return self._configPicker
end

function GameConfigServiceClient.Destroy(self: GameConfigServiceClient): ()
	self._maid:DoCleaning()
end

return GameConfigServiceClient
