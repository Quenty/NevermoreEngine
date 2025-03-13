--[=[
	@class PlayerKillTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local _ServiceBag = require("ServiceBag")

local PlayerKillTracker = setmetatable({}, BaseObject)
PlayerKillTracker.ClassName = "PlayerKillTracker"
PlayerKillTracker.__index = PlayerKillTracker

function PlayerKillTracker.new(scoreObject, serviceBag: _ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(scoreObject), PlayerKillTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService)

	self._player = self._obj.Parent
	assert(self._player and self._player:IsA("Player"), "Bad player")

	self._maid:GiveTask(
		self._deathReportService:ObservePlayerKillerReports(self._player):Subscribe(function(deathReport)
			assert(deathReport.killerPlayer == self._player, "Bad player")
			self._obj.Value = self._obj.Value + 1
		end)
	)

	return self
end

function PlayerKillTracker:GetKillValue()
	return self._obj
end

function PlayerKillTracker:GetPlayer(): Player
	return self._obj.Parent
end

function PlayerKillTracker:GetKills(): number
	return self._obj.Value
end

return PlayerKillTracker