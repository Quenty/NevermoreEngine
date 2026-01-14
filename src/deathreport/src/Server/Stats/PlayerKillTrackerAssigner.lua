--!strict
--[=[
	@class PlayerKillTrackerAssigner
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local DeathReportBindersServer = require("DeathReportBindersServer")
local Maid = require("Maid")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")
local ServiceBag = require("ServiceBag")

local PlayerKillTrackerAssigner = setmetatable({}, BaseObject)
PlayerKillTrackerAssigner.ClassName = "PlayerKillTrackerAssigner"
PlayerKillTrackerAssigner.__index = PlayerKillTrackerAssigner

export type PlayerKillTrackerAssigner =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportBindersServer: any,
			_killTrackers: { [Player]: Instance },
		},
		{} :: typeof({ __index = PlayerKillTrackerAssigner })
	))
	& BaseObject.BaseObject

function PlayerKillTrackerAssigner.new(serviceBag: ServiceBag.ServiceBag): PlayerKillTrackerAssigner
	local self: PlayerKillTrackerAssigner = setmetatable(BaseObject.new() :: any, PlayerKillTrackerAssigner)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportBindersServer = self._serviceBag:GetService(DeathReportBindersServer)

	self._killTrackers = {}

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayerAdded(player)
	end))
	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))

	for _, player in Players:GetPlayers() do
		self:_handlePlayerAdded(player)
	end

	return self
end

function PlayerKillTrackerAssigner.GetPlayerKills(self: PlayerKillTrackerAssigner, player: Player): number?
	local tracker = self:GetPlayerKillTracker(player)
	if tracker then
		return tracker:GetKills()
	else
		return nil
	end
end

function PlayerKillTrackerAssigner.GetPlayerKillTracker(self: PlayerKillTrackerAssigner, player: Player)
	local trackerInstance = self._killTrackers[player]
	if trackerInstance then
		return self._deathReportBindersServer.PlayerKillTracker:Get(trackerInstance)
	else
		return nil
	end
end

function PlayerKillTrackerAssigner._handlePlayerRemoving(self: PlayerKillTrackerAssigner, player: Player)
	self._maid[player] = nil
end

function PlayerKillTrackerAssigner._handlePlayerAdded(self: PlayerKillTrackerAssigner, player: Player)
	local maid = Maid.new()

	local killTracker = PlayerKillTrackerUtils.create(self._deathReportBindersServer.PlayerKillTracker, player)
	maid:GiveTask(killTracker)

	self._killTrackers[player] = killTracker

	maid:GiveTask(function()
		self._killTrackers[player] = nil
	end)

	local deathTracker = PlayerKillTrackerUtils.create(self._deathReportBindersServer.PlayerDeathTracker, player)
	maid:GiveTask(deathTracker)

	self._maid[player] = maid
end

return PlayerKillTrackerAssigner
