--!strict
--[=[
	@class GameConfigDataService
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigPicker = require("GameConfigPicker")
local ServiceBag = require("ServiceBag")

local GameConfigDataService = {}
GameConfigDataService.ServiceName = "GameConfigDataService"

export type GameConfigDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_configPicker: GameConfigPicker.GameConfigPicker,
	},
	{} :: typeof({ __index = GameConfigDataService })
))

function GameConfigDataService.Init(self: GameConfigDataService, serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

function GameConfigDataService.SetConfigPicker(
	self: GameConfigDataService,
	configPicker: GameConfigPicker.GameConfigPicker
)
	self._configPicker = configPicker
end

function GameConfigDataService.GetConfigPicker(self: GameConfigDataService): GameConfigPicker.GameConfigPicker
	return self._configPicker
end

return GameConfigDataService
