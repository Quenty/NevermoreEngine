--!strict
--[=[
	@class GameConfigCommandServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigCmdrUtils = require("GameConfigCmdrUtils")
local GameVersionUtils = require("GameVersionUtils")
local Maid = require("Maid")
local Rx = require("Rx")
local RxStateStackUtils = require("RxStateStackUtils")
local ServiceBag = require("ServiceBag")

-- Shown when there is no active game config to name the place after.
local DEFAULT_PLACE_NAME = "Cmdr"

local GameConfigCommandServiceClient = {}
GameConfigCommandServiceClient.ServiceName = "GameConfigCommandServiceClient"

export type GameConfigCommandServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_gameConfigServiceClient: any,
	},
	{} :: typeof({ __index = GameConfigCommandServiceClient })
))

function GameConfigCommandServiceClient.Init(
	self: GameConfigCommandServiceClient,
	serviceBag: ServiceBag.ServiceBag
): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrServiceClient"))
	self._gameConfigServiceClient = self._serviceBag:GetService(require("GameConfigServiceClient"))
end

function GameConfigCommandServiceClient.Start(self: GameConfigCommandServiceClient): ()
	self:_setupCommands()
end

function GameConfigCommandServiceClient._setupCommands(self: GameConfigCommandServiceClient): ()
	local picker = self._gameConfigServiceClient:GetConfigPicker()

	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		GameConfigCmdrUtils.registerAssetTypes(cmdr, picker)

		local latestConfig = RxStateStackUtils.createStateStack(picker:ObserveActiveConfigsBrio())
		self._maid:GiveTask(latestConfig)

		local configName = (latestConfig :: any):Observe():Pipe({
			Rx.switchMap(function(config): any
				if config then
					return config:ObserveConfigName()
				else
					return Rx.of(nil)
				end
			end),
		})

		-- The environment tells you whether the command you are about to run
		-- lands on production or on a test deploy, so it is worth the prompt
		-- real estate. It is absent in studio and in undeployed places, where
		-- the prompt stays exactly as it was.
		self._maid:GiveTask(Rx.combineLatest({
			name = configName,
			environment = GameVersionUtils.observeEnvironmentName(),
		}):Subscribe(function(state)
			local name = state.name or DEFAULT_PLACE_NAME

			if state.environment then
				cmdr:SetPlaceName(string.format("%s:%s", name, state.environment))
			else
				cmdr:SetPlaceName(name)
			end
		end))
	end)
end

function GameConfigCommandServiceClient.Destroy(self: GameConfigCommandServiceClient): ()
	self._maid:DoCleaning()
end

return GameConfigCommandServiceClient
