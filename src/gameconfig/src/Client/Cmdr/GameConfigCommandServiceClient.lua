--!strict
--[=[
	@class GameConfigCommandServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigCmdrUtils = require("GameConfigCmdrUtils")
local Maid = require("Maid")
local Rx = require("Rx")
local RxStateStackUtils = require("RxStateStackUtils")
local ServiceBag = require("ServiceBag")

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
	-- TODO: Determine production vs. staging and set cmdr annotation accordingly.

	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		GameConfigCmdrUtils.registerAssetTypes(cmdr, picker)

		local latestConfig = RxStateStackUtils.createStateStack(picker:ObserveActiveConfigsBrio())
		self._maid:GiveTask(latestConfig)

		self._maid:GiveTask((latestConfig :: any)
			:Observe()
			:Pipe({
				Rx.switchMap(function(config): any
					if config then
						return config:ObserveConfigName()
					else
						return Rx.of(nil)
					end
				end),
			})
			:Subscribe(function(name)
				if name then
					cmdr:SetPlaceName(name)
				else
					-- Default value
					cmdr:SetPlaceName("Cmdr")
				end
			end))
	end)
end

function GameConfigCommandServiceClient.Destroy(self: GameConfigCommandServiceClient): ()
	self._maid:DoCleaning()
end

return GameConfigCommandServiceClient
