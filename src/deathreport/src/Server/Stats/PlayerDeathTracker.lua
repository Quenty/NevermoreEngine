--[=[
	@class PlayerDeathTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local _ServiceBag = require("ServiceBag")

local PlayerDeathTracker = setmetatable({}, BaseObject)
PlayerDeathTracker.ClassName = "PlayerDeathTracker"
PlayerDeathTracker.__index = PlayerDeathTracker

function PlayerDeathTracker.new(scoreObject, serviceBag: _ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(scoreObject), PlayerDeathTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService)

	self._player = self._obj.Parent

	assert(self._player and self._player:IsA("Player"), "Bad player")

	self._maid:GiveTask(self._deathReportService:ObservePlayerDeathReports(self._player):Subscribe(function(deathReport)
		assert(deathReport.player == self._player, "Bad player")
		self._obj.Value = self._obj.Value + 1
	end))

	return self
end

return PlayerDeathTracker