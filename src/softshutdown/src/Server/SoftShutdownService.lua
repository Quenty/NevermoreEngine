--[=[
	This service lets you shut down servers without losing a bunch of players.
	When game.OnClose is called, the script teleports everyone in the server
	into a reserved server.

	When the reserved servers start up, they wait a few seconds, and then
	send everyone back into the main place.

	Originally written by Merely
	https://github.com/MerelyRBLX/ROBLOX-Lua/blob/master/SoftShutdown.lua

	Modified by Quenty

	@class SoftShutdownService
]=]

local require = require(script.Parent.loader).load(script)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local Promise = require("Promise")
local SoftShutdownConstants = require("SoftShutdownConstants")
local TeleportServiceUtils = require("TeleportServiceUtils")
local _ServiceBag = require("ServiceBag")

local SoftShutdownService = {}
SoftShutdownService.ServiceName = "SoftShutdownService"

--[=[
	Initialize the service. Should be done via [ServiceBag].

	:::warning
	Initializing this service effectively initializes side effects, which is, to initialize
	the soft shutdown behavior.
	:::

	@param serviceBag ServiceBag
]=]
function SoftShutdownService:Init(serviceBag: _ServiceBag.ServiceBag)
	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))
	self._serviceBag:GetService(require("SoftShutdownTranslator"))

	self._dataStore = DataStoreService:GetDataStore("IsSoftShutdownServer")

	self:_promiseIsLobby():Then(function(isLobby)
		if isLobby then
			self:_promiseRedirectAllPlayers()
		else
			self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
				return self:_promiseTeleportPlayersToLobby()
			end))
		end
	end)
end

function SoftShutdownService:_isReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function SoftShutdownService:_promiseIsLobby()
	if not self:_isReservedServer() then
		return Promise.resolved(false)
	end

	return self._maid:GivePromise(DataStorePromises.getAsync(self._dataStore, game.PrivateServerId))
end

function SoftShutdownService:_promiseTeleportPlayersToLobby()
	local players = Players:GetPlayers()
	if RunService:IsStudio() or #players == 0 or game.JobId == "" then
		return Promise.resolved()
	end

	Workspace:SetAttribute(SoftShutdownConstants.IS_SOFT_SHUTDOWN_UPDATING_ATTRIBUTE, true)

	local initialTeleportOptions = Instance.new("TeleportOptions")
	initialTeleportOptions.ShouldReserveServer = true
	initialTeleportOptions:SetTeleportData({
		isSoftShutdownReserveServer = true;
	})

	-- Collect any players remaining
	local remainingPlayers = {}
	self._maid._playerAddedCollector = Players.PlayerAdded:Connect(function(player)
		table.insert(remainingPlayers, player)
	end)

	return Promise.spawn(function(resolve, _reject)
		-- Wait to let the teleport GUI be set
		task.delay(1, resolve)
	end):Then(function()
		return TeleportServiceUtils.promiseTeleport(game.PlaceId, players, initialTeleportOptions)
	end)
		:Then(function(teleportResult)
			self._maid._playerAddedCollector = nil

			-- Construct new teleport options
			local newTeleportOptions = Instance.new("TeleportOptions")
			newTeleportOptions.ServerInstanceId = teleportResult.PrivateServerId
			newTeleportOptions.ReservedServerAccessCode = teleportResult.ReservedServerAccessCode
			newTeleportOptions:SetTeleportData({
				isSoftShutdownReserveServer = true;
			})

			-- Teleport any players that joined during initial teleport
			local promises = {}

			if #remainingPlayers > 0 then
				table.insert(promises, TeleportServiceUtils.promiseTeleport(game.PlaceId, remainingPlayers, newTeleportOptions))
			end

			self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
				table.insert(promises, TeleportServiceUtils.promiseTeleport(game.PlaceId, { player }, newTeleportOptions))
			end))

			-- We hope this works!
			table.insert(promises, DataStorePromises.setAsync(self._dataStore, teleportResult.PrivateServerId, true))

			return Promise.spawn(function(resolve)
				while #Players:GetPlayers() > 0 and self:_containsPending(promises) do
					task.wait(1)
				end

				resolve()
			end)
		end)
end

function SoftShutdownService:_containsPending(promises)
	for _, item in promises do
		if item:IsPending() then
			return true
		end
	end

	return false
end

function SoftShutdownService:_promiseRedirectAllPlayers()
	Workspace:SetAttribute(SoftShutdownConstants.IS_SOFT_SHUTDOWN_LOBBY_ATTRIBUTE, true)

	-- Wait for some players
	return Promise.spawn(function(resolve, reject)
		task.wait(1) -- Let the teleport GUI be set
		local players = Players:GetPlayers()
		while #players <= 0 do
			task.wait(1)
			players = Players:GetPlayers()
		end

		self._maid:GiveTask(reject)

		resolve(players)
	end)
		:Then(function(players)
			local teleportOptions = Instance.new("TeleportOptions")
			teleportOptions:SetTeleportData({
				isSoftShutdownArrivingIntoUpdatedServer = true;
			})

			-- Teleport all remaining players
			self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
				task.wait(1) -- Let the teleport GUI be set
				TeleportServiceUtils.promiseTeleport(game.PlaceId, { player }, teleportOptions)
			end))

			-- Try to keep players in the same group
			return TeleportServiceUtils.promiseTeleport(game.PlaceId, players, teleportOptions)
		end)
end

function SoftShutdownService:Destroy()
	self._maid:DoCleaning()
end

return SoftShutdownService
