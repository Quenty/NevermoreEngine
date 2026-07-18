--!strict
--[=[
	Server half of the streaming-cinematics system. Receives a focus position from a client
	(who has no character, or whose character is far from a cinematic camera) and points that
	player's `ReplicationFocus` at it via a [ReplicationFocusTracker], so world content streams
	in around the cinematic camera. Sending nil clears it.

	@server
	@class StreamingCinematicsService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local Remoting = require("Remoting")
local ReplicationFocusTracker = require("ReplicationFocusTracker")

local StreamingCinematicsService = {}
StreamingCinematicsService.ServiceName = "StreamingCinematicsService"

export type StreamingCinematicsService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_trackers: { [Player]: ReplicationFocusTracker.ReplicationFocusTracker },
		_remoting: any,
	},
	{} :: typeof({ __index = StreamingCinematicsService })
))

function StreamingCinematicsService.Init(self: StreamingCinematicsService): ()
	assert(not (self :: any)._remoting, "Already initialized")
	self._maid = Maid.new()

	self._trackers = {}

	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "StreamingCinematics"))
	self._remoting:DeclareEvent("SetFocus")

	self._maid:GiveTask(self._remoting.SetFocus:Connect(function(player: Player, position: Vector3?)
		self:_setFocus(player, position)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self:_clearFocus(player)
	end))
end

function StreamingCinematicsService._setFocus(
	self: StreamingCinematicsService,
	player: Player,
	position: Vector3?
): ()
	if position == nil then
		self:_clearFocus(player)
		return
	end

	if typeof(position) ~= "Vector3" then
		return
	end

	-- Never create a tracker for a player who is already leaving/gone; PlayerRemoving owns their
	-- cleanup, so a late remote must not resurrect per-player state.
	if not player:IsDescendantOf(game) then
		return
	end

	local tracker = self._trackers[player]
	if not tracker then
		tracker = ReplicationFocusTracker.new(player)
		self._trackers[player] = tracker
	end

	tracker:SetPosition(position)
end

function StreamingCinematicsService._clearFocus(self: StreamingCinematicsService, player: Player): ()
	local tracker = self._trackers[player]
	if tracker then
		tracker:Destroy()
		self._trackers[player] = nil
	end
end

function StreamingCinematicsService.Destroy(self: StreamingCinematicsService): ()
	for player in self._trackers do
		self:_clearFocus(player)
	end
	self._maid:DoCleaning()
end

return StreamingCinematicsService
