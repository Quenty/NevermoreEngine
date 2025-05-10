--!strict
--[=[
	Centralized humanoid tracking service.

	@class HumanoidTrackerService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local HumanoidTracker = require("HumanoidTracker")
local Maid = require("Maid")
local Observable = require("Observable")

local HumanoidTrackerService = {}
HumanoidTrackerService.ServiceName = "HumanoidTrackerService"

function HumanoidTrackerService:Init()
	assert(not self._maid, "Already initialized")
	self._maid = Maid.new()

	self._humanoidTrackerMap = {}

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self._maid[player] = nil
	end))
end

--[=[
	Gets a humanoid tracker for a given player

	@param player Player? -- If not set, uses local player
	@return HumanoidTracker
]=]
function HumanoidTrackerService:GetHumanoidTracker(player: Player?): HumanoidTracker.HumanoidTracker?
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer

	if player == nil then
		return nil
	end

	if self._humanoidTrackerMap[player] then
		return self._humanoidTrackerMap[player]
	else
		local maid = Maid.new()
		local tracker = maid:Add(HumanoidTracker.new(player))

		maid:GiveTask(function()
			self._maid[player] = nil
			self._humanoidTrackerMap[player] = nil
		end)

		self._maid[player] = maid
		self._humanoidTrackerMap[player] = tracker

		return tracker
	end
end

--[=[
	Gets a player's humanoid

	@param player Player? -- If not set, uses local player
	@return Humanoid?
]=]
function HumanoidTrackerService:GetHumanoid(player: Player?): Humanoid?
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer
	return self:GetHumanoidTracker(player).Humanoid.Value
end

--[=[
	Observe a player's humanoid

	@param player Player? -- If not set, uses local player
	@return Observable<Humanoid?>
]=]
function HumanoidTrackerService:ObserveHumanoid(player: Player?): Observable.Observable<Humanoid?>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer

	return self:GetHumanoidTracker(player).Humanoid:Observe()
end

--[=[
	Observe a player's humanoid

	@param player Player? -- If not set, uses local player
	@return Observable<Brio<Humanoid>>
]=]
function HumanoidTrackerService:ObserveHumanoidBrio(player: Player?): Observable.Observable<Brio.Brio<Humanoid>>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer

	return self:GetHumanoidTracker(player).Humanoid:ObserveBrio(function(value)
		return value ~= nil
	end)
end

--[=[
	Gets a player's alive humanoid

	@param player Player? -- If not set, uses local player
	@return Humanoid?
]=]
function HumanoidTrackerService:GetAliveHumanoid(player: Player?): Humanoid?
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer
	return self:GetHumanoidTracker(player).AliveHumanoid.Value
end

--[=[
	Observe a player's alive humanoid

	@param player Player? -- If not set, uses local player
	@return Observable<Humanoid?>
]=]
function HumanoidTrackerService:ObserveAliveHumanoid(player: Player?): Observable.Observable<Humanoid?>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer

	return self:GetHumanoidTracker(player).AliveHumanoid:Observe()
end

--[=[
	Observe a player's alive humanoid

	@param player Player? -- If not set, uses local player
	@return Observable<Brio<Humanoid>>
]=]
function HumanoidTrackerService:ObserveAliveHumanoidBrio(player: Player?)
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	player = player or Players.LocalPlayer

	return self:GetHumanoidTracker(player).AliveHumanoid:ObserveBrio(function(value)
		return value ~= nil
	end)
end

--[=[
	Cleans up the humanoid tracking service
]=]
function HumanoidTrackerService:Destroy()
	self._maid:DoCleaning()
end

return HumanoidTrackerService
