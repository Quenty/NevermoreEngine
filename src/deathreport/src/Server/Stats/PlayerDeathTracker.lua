--!strict
--[=[
	@class PlayerDeathTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local ServiceBag = require("ServiceBag")

local PlayerDeathTracker = setmetatable({}, BaseObject)
PlayerDeathTracker.ClassName = "PlayerDeathTracker"
PlayerDeathTracker.__index = PlayerDeathTracker

export type PlayerDeathTracker =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_player: Player,
		},
		{} :: typeof({ __index = PlayerDeathTracker })
	))
	& BaseObject.BaseObject

function PlayerDeathTracker.new(scoreObject: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerDeathTracker
	local self: PlayerDeathTracker = setmetatable(BaseObject.new(scoreObject) :: any, PlayerDeathTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	local player = self._obj.Parent
	assert(player and player:IsA("Player"), "Bad player")
	self._player = player

	self._maid:GiveTask(self._deathReportService:ObservePlayerDeathReports(self._player):Subscribe(function(deathReport)
		assert(deathReport.player == self._player, "Bad player")
		self._obj.Value = self._obj.Value + 1
	end))

	return self
end

return PlayerDeathTracker
