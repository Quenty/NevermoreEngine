--!strict
--[=[
	Gives every player a [PlayerKillTracker] and a [PlayerDeathTracker] for as long as they are in
	the game.

	@server
	@class PlayerKillTrackerAssigner
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local Maid = require("Maid")
local PlayerDeathTracker = require("PlayerDeathTracker")
local PlayerKillTracker = require("PlayerKillTracker")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local PlayerKillTrackerAssigner = setmetatable({}, BaseObject)
PlayerKillTrackerAssigner.ClassName = "PlayerKillTrackerAssigner"
PlayerKillTrackerAssigner.__index = PlayerKillTrackerAssigner

export type PlayerKillTrackerAssigner =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_playerKillTrackerBinder: Binder.Binder<PlayerKillTracker.PlayerKillTracker>,
			_playerDeathTrackerBinder: Binder.Binder<PlayerDeathTracker.PlayerDeathTracker>,
			_killTrackers: { [Player]: Instance },
		},
		{} :: typeof({ __index = PlayerKillTrackerAssigner })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerKillTrackerAssigner. The service bag must carry [DeathReportService].

	@param serviceBag ServiceBag
	@return PlayerKillTrackerAssigner
]=]
function PlayerKillTrackerAssigner.new(serviceBag: ServiceBag.ServiceBag): PlayerKillTrackerAssigner
	local self: PlayerKillTrackerAssigner = setmetatable(BaseObject.new() :: any, PlayerKillTrackerAssigner)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerKillTrackerBinder = self._serviceBag:GetService(PlayerKillTracker)
	self._playerDeathTrackerBinder = self._serviceBag:GetService(PlayerDeathTracker)

	self._killTrackers = {}

	local function handlePlayerAdded(player: Player)
		self:_handlePlayerAdded(player)
	end

	local function handlePlayerRemoving(player: Player)
		self:_handlePlayerRemoving(player)
	end

	self._maid:GiveTask(Players.PlayerAdded:Connect(handlePlayerAdded))
	self._maid:GiveTask(Players.PlayerRemoving:Connect(handlePlayerRemoving))

	-- Mocks are invisible to the Players service, so their tag lifecycle is the counterpart of
	-- the join events, feeding the same handlers.
	self._maid:GiveTask(PlayerMock.getMockAddedSignal():Connect(handlePlayerAdded))
	self._maid:GiveTask(PlayerMock.getMockRemovingSignal():Connect(handlePlayerRemoving))

	for _, player in Players:GetPlayers() do
		self:_handlePlayerAdded(player)
	end

	for _, player in PlayerMock.getMocks() do
		self:_handlePlayerAdded(player)
	end

	return self
end

--[=[
	Returns the kills of the player, or nil if the player has no tracker

	@param player Player
	@return number?
]=]
function PlayerKillTrackerAssigner.GetPlayerKills(self: PlayerKillTrackerAssigner, player: Player): number?
	local tracker = self:GetPlayerKillTracker(player)
	if tracker then
		return tracker:GetKills()
	else
		return nil
	end
end

--[=[
	Returns the kill tracker of the player, if assigned and bound

	@param player Player
	@return PlayerKillTracker?
]=]
function PlayerKillTrackerAssigner.GetPlayerKillTracker(
	self: PlayerKillTrackerAssigner,
	player: Player
): PlayerKillTracker.PlayerKillTracker?
	local trackerInstance = self._killTrackers[player]
	if trackerInstance then
		return self._playerKillTrackerBinder:Get(trackerInstance)
	else
		return nil
	end
end

function PlayerKillTrackerAssigner._handlePlayerRemoving(self: PlayerKillTrackerAssigner, player: Player)
	self._maid[player] = nil
end

function PlayerKillTrackerAssigner._handlePlayerAdded(self: PlayerKillTrackerAssigner, player: Player)
	local maid = Maid.new()

	local killTracker = PlayerKillTrackerUtils.create(self._playerKillTrackerBinder, player)
	maid:GiveTask(killTracker)

	self._killTrackers[player] = killTracker

	maid:GiveTask(function()
		self._killTrackers[player] = nil
	end)

	local deathTracker = PlayerKillTrackerUtils.create(self._playerDeathTrackerBinder, player)
	maid:GiveTask(deathTracker)

	self._maid[player] = maid
end

return PlayerKillTrackerAssigner
