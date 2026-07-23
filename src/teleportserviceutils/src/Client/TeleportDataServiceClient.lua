--!strict
--[=[
	Client half of the symmetric teleport-data surface, mirroring [TeleportDataService]. Same build API
	(via a shared [TeleportDataBuilder]) and the same Promise-based read API, so a system queries arrived
	data the same way on either realm and gets the same answer.

	The client holds the full arrived payload natively: `TeleportService:GetLocalPlayerTeleportData()`
	returns *everything* the player teleported in with, regardless of which realm set it. So the unified
	read ([TeleportDataServiceClient.PromiseArrivedData]) resolves immediately from local data -- no
	round-trip. Two things still cross the network:

	* the client **replicates** its raw arrived payload to the server on start, because the server's join
	  data is blind to a client-initiated teleport; and
	* the client **pulls** its *trusted* band from the server
	  ([TeleportDataServiceClient.PromiseTrustedArrivedData]), because the client cannot tell, from its
	  own local data alone, which keys were server-authored.

	@client
	@class TeleportDataServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local TeleportDataBuilder = require("TeleportDataBuilder")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

export type TeleportDataProvider = TeleportDataBuilder.TeleportDataProvider
export type PerPlayerTeleportDataProvider = TeleportDataBuilder.PerPlayerTeleportDataProvider

-- Bounded wait for the server's trusted-band response; on timeout the trusted band reads as nil (we
-- could not prove any key trusted) rather than hanging the read.
local DEFAULT_TRUSTED_FETCH_TIMEOUT = 8

local TeleportDataServiceClient = {}
TeleportDataServiceClient.ServiceName = "TeleportDataServiceClient"

export type TeleportDataServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_builder: TeleportDataBuilder.TeleportDataBuilder,
		_remoting: any,
		-- The raw local teleport data (envelope or legacy flat), captured once. Kept raw so the slice can
		-- be re-derived and so the exact payload is what gets replicated to the server.
		_nonTrustedRaw: { [string]: any }?,
		_nonTrustedResolved: boolean,
		_read: boolean,
		-- Cached trusted-band fetch (server pull); boxed override stands in for the server in tests.
		_trustedPromise: any,
		_trustedOverride: { any }?,
		_trustedFetchTimeout: number,
	},
	{} :: typeof({ __index = TeleportDataServiceClient })
))

local function readLocalPlayerTeleportData(): { [string]: any }?
	local ok, teleportData = pcall(function()
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	if ok and type(teleportData) == "table" then
		return teleportData :: { [string]: any }
	end
	return nil
end

function TeleportDataServiceClient.Init(self: TeleportDataServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._nonTrustedRaw = nil
	self._nonTrustedResolved = false
	self._read = false
	self._trustedPromise = nil
	self._trustedOverride = nil
	self._trustedFetchTimeout = DEFAULT_TRUSTED_FETCH_TIMEOUT

	self._builder = TeleportDataBuilder.new(function(_player: Player): number
		return self:_getLocalUserId()
	end)

	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "TeleportDataService"))
end

function TeleportDataServiceClient.Start(self: TeleportDataServiceClient)
	-- Replicate unconditionally -- even a fresh join (no arrived data) sends the empty sentinel, so the
	-- server resolves promptly instead of waiting out its fallback timeout on every normal join.
	self._maid:GiveTask(self._remoting:PromiseFireServer("ReplicateArrivedData", self:_getNonTrustedRaw()))
end

--[=[
	Registers a shared provider. See [TeleportDataBuilder.RegisterTeleportDataProvider].

	@param provider TeleportDataProvider
	@return () -> ()
]=]
function TeleportDataServiceClient.RegisterTeleportDataProvider(
	self: TeleportDataServiceClient,
	provider: TeleportDataProvider
): () -> ()
	return self._builder:RegisterTeleportDataProvider(provider)
end

--[=[
	Registers a per-player provider. See [TeleportDataBuilder.RegisterPerPlayerTeleportDataProvider].

	@param provider PerPlayerTeleportDataProvider
	@return () -> ()
]=]
function TeleportDataServiceClient.RegisterPerPlayerTeleportDataProvider(
	self: TeleportDataServiceClient,
	provider: PerPlayerTeleportDataProvider
): () -> ()
	return self._builder:RegisterPerPlayerTeleportDataProvider(provider)
end

--[=[
	Builds the teleport data envelope for a teleport (typically `{ Players.LocalPlayer }`, since a client
	can only teleport itself). See [TeleportDataBuilder.BuildTeleportData].

	@param players { Player }
	@param baseData { [string]: any }?
	@return { [string]: any }
]=]
function TeleportDataServiceClient.BuildTeleportData(
	self: TeleportDataServiceClient,
	players: { Player },
	baseData: { [string]: any }?
): { [string]: any }
	return self._builder:BuildTeleportData(players, baseData)
end

--[=[
	Builds the teleport data envelope, awaiting any provider that returns a Promise. See
	[TeleportDataBuilder.PromiseBuildTeleportData].

	@param players { Player }
	@param baseData { [string]: any }?
	@return Promise<{ [string]: any }>
]=]
function TeleportDataServiceClient.PromiseBuildTeleportData(
	self: TeleportDataServiceClient,
	players: { Player },
	baseData: { [string]: any }?
): Promise.Promise<{ [string]: any }>
	return self._builder:PromiseBuildTeleportData(players, baseData)
end

--[=[
	Resolves the UserId used to select the local player's envelope slice. A method so tests can stand in a
	fixed id (a headless client has no `Players.LocalPlayer`), mirroring the server's `_getUserId`.

	@return number
]=]
function TeleportDataServiceClient._getLocalUserId(_self: TeleportDataServiceClient): number
	-- Headless (test) sessions have no Players.LocalPlayer; the designated PlayerMock stands in.
	-- Mirrors TeleportDataService._getUserId on the server.
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer == nil then
		return 0 -- No local identity at all; no envelope slice will match.
	end

	return if PlayerMock.isMock(localPlayer) then PlayerMock.read(localPlayer, "UserId") else localPlayer.UserId
end

--[=[
	Returns the *unified* teleport data the local player arrived with, or nil. Resolves immediately: the
	client's local teleport data already contains everything the player arrived with (trusted keys
	included), so the merge is a no-op here. Mirrors [TeleportDataService.PromiseArrivedData].

	@return Promise<{ [string]: any }?>
]=]
function TeleportDataServiceClient.PromiseArrivedData(self: TeleportDataServiceClient): any
	self._read = true
	return Promise.resolved(TeleportDataEnvelopeUtils.readSlice(self:_getNonTrustedRaw(), self:_getLocalUserId()))
end

--[=[
	Returns the trusted-band teleport data the local player arrived with (server-authored), or nil. Pulled
	from the server, which alone knows which keys came through its join data. Mirrors
	[TeleportDataService.PromiseTrustedArrivedData].

	@return Promise<{ [string]: any }?>
]=]
function TeleportDataServiceClient.PromiseTrustedArrivedData(self: TeleportDataServiceClient): any
	self._read = true
	return self:_promiseTrustedSlice()
end

--[=[
	Returns the non-trusted-band teleport data the local player arrived with (its own local data), or nil.
	This is the band the client replicates to the server. Mirrors
	[TeleportDataService.PromiseNonTrustedArrivedData].

	@return Promise<{ [string]: any }?>
]=]
function TeleportDataServiceClient.PromiseNonTrustedArrivedData(self: TeleportDataServiceClient): any
	self._read = true
	return Promise.resolved(TeleportDataEnvelopeUtils.readSlice(self:_getNonTrustedRaw(), self:_getLocalUserId()))
end

--[=[
	Returns the unified value the local player arrived with under `key`, or nil.

	@param key string
	@return Promise<any>
]=]
function TeleportDataServiceClient.PromiseArrivedValue(self: TeleportDataServiceClient, key: string): any
	assert(type(key) == "string", "Bad key")

	return self:PromiseArrivedData():Then(function(data)
		if type(data) == "table" then
			return data[key]
		end
		return nil
	end)
end

--[=[
	Returns whether the local player arrived with a unified value under `key`.

	@param key string
	@return Promise<boolean>
]=]
function TeleportDataServiceClient.PromiseHasArrivedValue(self: TeleportDataServiceClient, key: string): any
	return self:PromiseArrivedValue(key):Then(function(value)
		return value ~= nil
	end)
end

--[=[
	Returns the trusted-band value the local player arrived with under `key`, or nil.

	@param key string
	@return Promise<any>
]=]
function TeleportDataServiceClient.PromiseTrustedArrivedValue(self: TeleportDataServiceClient, key: string): any
	assert(type(key) == "string", "Bad key")

	return self:PromiseTrustedArrivedData():Then(function(data)
		if type(data) == "table" then
			return data[key]
		end
		return nil
	end)
end

--[=[
	Returns whether the local player arrived with a trusted-band value under `key`.

	@param key string
	@return Promise<boolean>
]=]
function TeleportDataServiceClient.PromiseHasTrustedArrivedValue(self: TeleportDataServiceClient, key: string): any
	return self:PromiseTrustedArrivedValue(key):Then(function(value)
		return value ~= nil
	end)
end

--[=[
	Returns whether the unified value for `key` came from the trusted band. Mirrors
	[TeleportDataService.PromiseArrivedValueIsTrusted].

	@param key string
	@return Promise<boolean>
]=]
function TeleportDataServiceClient.PromiseArrivedValueIsTrusted(self: TeleportDataServiceClient, key: string): any
	assert(type(key) == "string", "Bad key")

	return self:PromiseTrustedArrivedData():Then(function(trusted)
		return type(trusted) == "table" and trusted[key] ~= nil
	end)
end

--[=[
	Overrides the local (non-trusted) arrived band. Test seam -- headless test clients have no real
	teleport data. Must be called before anything reads.

	@param data { [string]: any }?
]=]
function TeleportDataServiceClient.SetNonTrustedArrivedTeleportDataForTesting(
	self: TeleportDataServiceClient,
	data: { [string]: any }?
)
	assert(
		not self._read,
		"Cannot set arrived teleport data after it has been read -- inject it before anything reads it"
	)

	self._nonTrustedRaw = data
	self._nonTrustedResolved = true
end

--[=[
	Overrides the trusted band the client would otherwise pull from the server. Test seam -- headless test
	clients have no server to invoke. Must be called before anything reads.

	@param data { [string]: any }?
]=]
function TeleportDataServiceClient.SetTrustedArrivedTeleportDataForTesting(
	self: TeleportDataServiceClient,
	data: { [string]: any }?
)
	assert(
		not self._read,
		"Cannot set trusted arrived data after it has been read -- inject it before anything reads it"
	)

	self._trustedOverride = { data }
end

--[=[
	Sets the bounded wait for the server's trusted-band response. Test seam.

	@param seconds number
]=]
function TeleportDataServiceClient.SetTrustedFetchTimeoutForTesting(self: TeleportDataServiceClient, seconds: number)
	assert(type(seconds) == "number", "Bad seconds")
	self._trustedFetchTimeout = seconds
end

function TeleportDataServiceClient._getNonTrustedRaw(self: TeleportDataServiceClient): { [string]: any }?
	if not self._nonTrustedResolved then
		self._nonTrustedRaw = readLocalPlayerTeleportData()
		self._nonTrustedResolved = true
	end
	return self._nonTrustedRaw
end

-- Resolves the trusted slice: a test override if set, else one cached server pull. On timeout or error
-- the trusted band reads as nil rather than hanging.
function TeleportDataServiceClient._promiseTrustedSlice(self: TeleportDataServiceClient): any
	if self._trustedOverride ~= nil then
		return Promise.resolved(self._trustedOverride[1])
	end

	if not self._trustedPromise then
		local fetch = self._remoting:PromiseInvokeServer("RequestTrustedArrivedData"):Then(function(slice)
			if type(slice) == "table" then
				return slice
			end
			return nil
		end)

		self._trustedPromise = Promise.new()
		self._trustedPromise:Resolve(fetch)
		task.delay(self._trustedFetchTimeout, function()
			-- A missing server response leaves trust unprovable; resolve to nil so reads never hang.
			self._trustedPromise:Resolve(nil)
		end)
	end

	return self._trustedPromise
end

function TeleportDataServiceClient.Destroy(self: TeleportDataServiceClient)
	self._maid:Destroy()
end

return TeleportDataServiceClient
