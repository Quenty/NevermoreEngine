--!strict
--[=[
	Registers the game product cmdr types on the client so cmdr can autocomplete the
	`set-ownership` command's arguments. The commands themselves are registered on the server by
	[GameProductCmdrService]; only the shared types need to exist on the client for autocomplete.

	@client
	@class GameProductCmdrServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GameProductCmdrTypeUtils = require("GameProductCmdrTypeUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local GameProductCmdrServiceClient = {}
GameProductCmdrServiceClient.ServiceName = "GameProductCmdrServiceClient"

export type GameProductCmdrServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_gameConfigServiceClient: any,
	},
	{} :: typeof({ __index = GameProductCmdrServiceClient })
))

function GameProductCmdrServiceClient.Init(self: GameProductCmdrServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrServiceClient"))
	self._gameConfigServiceClient = self._serviceBag:GetService(require("GameConfigServiceClient"))
end

function GameProductCmdrServiceClient.Start(self: GameProductCmdrServiceClient): ()
	local configPicker = self._gameConfigServiceClient:GetConfigPicker()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		GameProductCmdrTypeUtils.registerTypes(cmdr, configPicker)
	end)
end

function GameProductCmdrServiceClient.Destroy(self: GameProductCmdrServiceClient): ()
	self._maid:DoCleaning()
end

return GameProductCmdrServiceClient
