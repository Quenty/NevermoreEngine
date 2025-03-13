--[=[
	@class GameConfigCommandServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigCmdrUtils = require("GameConfigCmdrUtils")
local Maid = require("Maid")
local RxStateStackUtils = require("RxStateStackUtils")
local Rx = require("Rx")
local _ServiceBag = require("ServiceBag")

local GameConfigCommandServiceClient = {}
GameConfigCommandServiceClient.ServiceName = "GameConfigCommandServiceClient"

function GameConfigCommandServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrServiceClient"))
	self._gameConfigServiceClient = self._serviceBag:GetService(require("GameConfigServiceClient"))
end

function GameConfigCommandServiceClient:Start()
	self:_setupCommands()
end

function GameConfigCommandServiceClient:_setupCommands()
	local picker = self._gameConfigServiceClient:GetConfigPicker()
	-- TODO: Determine production vs. staging and set cmdr annotation accordingly.


	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		GameConfigCmdrUtils.registerAssetTypes(cmdr, picker)

		local latestConfig = RxStateStackUtils.createStateStack(picker:ObserveActiveConfigsBrio())
		self._maid:GiveTask(latestConfig)

		self._maid:GiveTask(latestConfig:Observe():Pipe({
			Rx.switchMap(function(config)
				if config then
					return config:ObserveConfigName()
				else
					return Rx.of(nil)
				end
			end)
		}):Subscribe(function(name)
			if name then
				cmdr:SetPlaceName(name)
			else
				-- Default value
				cmdr:SetPlaceName("Cmdr")
			end
		end))
	end)
end

function GameConfigCommandServiceClient:Destroy()
	self._maid:DoCleaning()
end

return GameConfigCommandServiceClient