--!strict
--[=[
	Server half of the symmetric teleport-data surface. Two responsibilities:

	* **Building** teleport data through a shared [TeleportDataBuilder], so every teleport site assembles
	  the same envelope from the same providers (see [TeleportDataService.BuildTeleportData]).
	* **Reading** the data a player arrived with, as a *unified* view across two trust bands.

	The trust split is the load-bearing idea. A player's arrived data reaches the server two ways:

	* the **trusted** band -- `player:GetJoinData().TeleportData` -- which Roblox only populates for a
	  *server*-initiated teleport, so it is genuinely server-authored and safe to authorize on; and
	* the **non-trusted** band -- what the *client* read from its own local teleport data
	  (`GetLocalPlayerTeleportData`) and replicated back to us. A client-initiated teleport (e.g. a menu
	  teleporting the local player) only ever reaches the server this way, so without it the server is
	  blind to data the client can see.

	The unified read ([TeleportDataService.PromiseArrivedData]) merges both with the **trusted band
	winning**, so a client can never override a key the server set. Because the non-trusted band arrives
	over the network, every read is a [Promise]: it resolves once the client has replicated (or a bounded
	timeout falls back to the trusted band alone, so a stale client can never hang a read forever). A
	[PlayerMock] has no client to wait for, so its reads fall back at the next resumption step instead of
	the production window -- a spec injects arrived data (via the testing seams) before yielding. Code
	that must *not* trust the client reads the trusted band explicitly via
	[TeleportDataService.PromiseTrustedArrivedData]; the unified accessor is deliberately un-named for
	trust so trusting client data is always a visible choice.

	@server
	@class TeleportDataService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local TeleportDataBuilder = require("TeleportDataBuilder")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

export type TeleportDataProvider = TeleportDataBuilder.TeleportDataProvider
export type PerPlayerTeleportDataProvider = TeleportDataBuilder.PerPlayerTeleportDataProvider

-- Bounded wait for the client's replication before a read falls back to the trusted band alone. Long
-- enough to cover a normal join round-trip, short enough that a client that never replicates (crashed,
-- outdated) cannot stall a slot-load indefinitely.
local DEFAULT_REPLICATION_TIMEOUT = 8

-- Per-player arrival state. The first of {replication arrives, timeout fires, player leaves} *seals* the
-- entry: it snapshots both raw bands and resolves `promise`, so every reader -- now or later -- computes
-- the identical unified view. Later replications are ignored (first-wins), preserving one agreed answer.
type ArrivalEntry = {
	maid: Maid.Maid,
	promise: any,
	sealed: boolean,
	-- Boxed test override for the trusted band ({ raw }); nil means read from real join data.
	trustedOverride: { any }?,
	-- Snapshotted at seal time so reads never re-read a changing source.
	trustedRaw: any,
	nonTrustedRaw: any,
	-- Set once a read has been requested; injecting a trusted override afterwards would disagree with
	-- what that reader will see, so the seam asserts against it.
	read: boolean,
	resolve: (nonTrustedRaw: any) -> (),
}

local TeleportDataService = {}
TeleportDataService.ServiceName = "TeleportDataService"

export type TeleportDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_builder: TeleportDataBuilder.TeleportDataBuilder,
		_remoting: any,
		_entries: { [Player]: ArrivalEntry },
		_replicationTimeout: number,
	},
	{} :: typeof({ __index = TeleportDataService })
))

function TeleportDataService.Init(self: TeleportDataService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._entries = {}
	self._replicationTimeout = DEFAULT_REPLICATION_TIMEOUT
	-- The builder shares the service's UserId resolver so a test override of `_getUserId` keys both the
	-- built envelope and the arrived-data reads the same way.
	self._builder = TeleportDataBuilder.new(function(player: Player): number
		return self:_getUserId(player)
	end)

	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "TeleportDataService"))

	-- Client pushes the raw teleport data it arrived with; we store it as that player's non-trusted band,
	-- keyed by the *authenticated* sender (never any UserId embedded in the payload).
	self._maid:GiveTask(self._remoting:Connect("ReplicateArrivedData", function(player: Player, raw: any)
		self:_onReplicated(player, raw)
	end))

	-- Client pulls its trusted band -- the part it cannot distinguish inside its own local teleport data.
	self._maid:GiveTask(self._remoting:Bind("RequestTrustedArrivedData", function(player: Player): any
		return TeleportDataEnvelopeUtils.readSlice(self:_getTrustedRaw(player), self:_getUserId(player))
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self:_cleanupPlayer(player)
	end))
end

--[=[
	Registers a shared provider (contributes to every player's teleport data). See
	[TeleportDataBuilder.RegisterTeleportDataProvider]. Returns an unregister function.

	@param provider TeleportDataProvider
	@return () -> ()
]=]
function TeleportDataService.RegisterTeleportDataProvider(
	self: TeleportDataService,
	provider: TeleportDataProvider
): () -> ()
	return self._builder:RegisterTeleportDataProvider(provider)
end

--[=[
	Registers a per-player provider. See [TeleportDataBuilder.RegisterPerPlayerTeleportDataProvider].
	Returns an unregister function.

	@param provider PerPlayerTeleportDataProvider
	@return () -> ()
]=]
function TeleportDataService.RegisterPerPlayerTeleportDataProvider(
	self: TeleportDataService,
	provider: PerPlayerTeleportDataProvider
): () -> ()
	return self._builder:RegisterPerPlayerTeleportDataProvider(provider)
end

--[=[
	Builds the teleport data envelope for a teleport of the given players. See
	[TeleportDataBuilder.BuildTeleportData].

	@param players { Player }
	@param baseData { [string]: any }?
	@return { [string]: any }
]=]
function TeleportDataService.BuildTeleportData(
	self: TeleportDataService,
	players: { Player },
	baseData: { [string]: any }?
): { [string]: any }
	return self._builder:BuildTeleportData(players, baseData)
end

--[=[
	Resolves the UserId used to key a player's envelope slice. A method so tests can stand in a fake
	player (which has no UserId) by overriding it.

	@param player Player
	@return number
]=]
function TeleportDataService._getUserId(_self: TeleportDataService, player: Player): number
	return if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId
end

--[=[
	Returns the *unified* teleport data the player arrived with -- the trusted band (server join data)
	merged over the non-trusted band (client-replicated), trusted winning -- or nil. Resolves once the
	client has replicated its band, or when the bounded timeout falls back to the trusted band alone.

	This is the everyday accessor. It may contain client-authored keys, so treat it as a *request*, not
	an authority; for authoritative reads use [TeleportDataService.PromiseTrustedArrivedData].

	@param player Player
	@return Promise<{ [string]: any }?>
]=]
function TeleportDataService.PromiseArrivedData(self: TeleportDataService, player: Player): any
	assert(typeof(player) == "Instance", "Bad player")

	local entry = self:_getEntry(player)
	entry.read = true
	return entry.promise:Then(function()
		return TeleportDataEnvelopeUtils.readMergedSlice(entry.trustedRaw, entry.nonTrustedRaw, self:_getUserId(player))
	end)
end

--[=[
	Returns the trusted-band teleport data the player arrived with (server-authored, from join data), or
	nil. Safe to authorize on -- a client can never place data here. Resolves once the arrival is sealed.

	@param player Player
	@return Promise<{ [string]: any }?>
]=]
function TeleportDataService.PromiseTrustedArrivedData(self: TeleportDataService, player: Player): any
	assert(typeof(player) == "Instance", "Bad player")

	local entry = self:_getEntry(player)
	entry.read = true
	return entry.promise:Then(function()
		return TeleportDataEnvelopeUtils.readSlice(entry.trustedRaw, self:_getUserId(player))
	end)
end

--[=[
	Returns the non-trusted-band teleport data the player arrived with (client-replicated), or nil.
	Rarely needed directly; prefer the unified [TeleportDataService.PromiseArrivedData].

	@param player Player
	@return Promise<{ [string]: any }?>
]=]
function TeleportDataService.PromiseNonTrustedArrivedData(self: TeleportDataService, player: Player): any
	assert(typeof(player) == "Instance", "Bad player")

	local entry = self:_getEntry(player)
	entry.read = true
	return entry.promise:Then(function()
		return TeleportDataEnvelopeUtils.readSlice(entry.nonTrustedRaw, self:_getUserId(player))
	end)
end

--[=[
	Returns the unified value the player arrived with under `key`, or nil.

	@param player Player
	@param key string
	@return Promise<any>
]=]
function TeleportDataService.PromiseArrivedValue(self: TeleportDataService, player: Player, key: string): any
	assert(type(key) == "string", "Bad key")

	return self:PromiseArrivedData(player):Then(function(data)
		if type(data) == "table" then
			return data[key]
		end
		return nil
	end)
end

--[=[
	Returns whether the player arrived with a unified value under `key`.

	@param player Player
	@param key string
	@return Promise<boolean>
]=]
function TeleportDataService.PromiseHasArrivedValue(self: TeleportDataService, player: Player, key: string): any
	return self:PromiseArrivedValue(player, key):Then(function(value)
		return value ~= nil
	end)
end

--[=[
	Returns the trusted-band value the player arrived with under `key`, or nil. Safe to authorize on.

	@param player Player
	@param key string
	@return Promise<any>
]=]
function TeleportDataService.PromiseTrustedArrivedValue(self: TeleportDataService, player: Player, key: string): any
	assert(type(key) == "string", "Bad key")

	return self:PromiseTrustedArrivedData(player):Then(function(data)
		if type(data) == "table" then
			return data[key]
		end
		return nil
	end)
end

--[=[
	Returns whether the player arrived with a trusted-band value under `key`.

	@param player Player
	@param key string
	@return Promise<boolean>
]=]
function TeleportDataService.PromiseHasTrustedArrivedValue(self: TeleportDataService, player: Player, key: string): any
	return self:PromiseTrustedArrivedValue(player, key):Then(function(value)
		return value ~= nil
	end)
end

--[=[
	Returns whether the unified value for `key` came from the trusted band -- i.e. whether it is safe to
	authorize on. Defense-in-depth for code that reads the unified view but must occasionally assert
	provenance without a second read.

	@param player Player
	@param key string
	@return Promise<boolean>
]=]
function TeleportDataService.PromiseArrivedValueIsTrusted(self: TeleportDataService, player: Player, key: string): any
	assert(type(key) == "string", "Bad key")

	local entry = self:_getEntry(player)
	entry.read = true
	return entry.promise:Then(function()
		local trusted = TeleportDataEnvelopeUtils.readSlice(entry.trustedRaw, self:_getUserId(player))
		return type(trusted) == "table" and trusted[key] ~= nil
	end)
end

--[=[
	Overrides the *trusted* arrived band for a player. Test seam -- headless servers have no join data, so
	specs inject what a player would have arrived with from a server teleport. Must be set before any read
	seals the arrival.

	@param player Player
	@param data { [string]: any }?
]=]
function TeleportDataService.SetTrustedArrivedTeleportDataForTesting(
	self: TeleportDataService,
	player: Player,
	data: { [string]: any }?
)
	assert(typeof(player) == "Instance", "Bad player")

	local entry = self:_getEntry(player)
	assert(not entry.sealed, "Cannot set trusted arrived data after the arrival has sealed")
	assert(not entry.read, "Cannot set trusted arrived data after it has been read -- inject it first")
	entry.trustedOverride = { data }
end

--[=[
	Simulates the client's non-trusted band arriving (the replication the real client pushes). Test seam.
	First arrival wins and seals; later calls are ignored, mirroring production first-wins semantics.

	@param player Player
	@param data { [string]: any }?
]=]
function TeleportDataService.SetNonTrustedArrivedTeleportDataForTesting(
	self: TeleportDataService,
	player: Player,
	data: { [string]: any }?
)
	assert(typeof(player) == "Instance", "Bad player")

	self:_onReplicated(player, data)
end

--[=[
	Sets the bounded wait before a read falls back to the trusted band alone. Test seam, so a spec can
	drive the timeout path deterministically without waiting the production window.

	@param seconds number
]=]
function TeleportDataService.SetReplicationTimeoutForTesting(self: TeleportDataService, seconds: number)
	assert(type(seconds) == "number", "Bad seconds")
	self._replicationTimeout = seconds
end

function TeleportDataService._getTrustedRaw(self: TeleportDataService, player: Player): any
	local entry = self._entries[player]
	if entry and entry.trustedOverride ~= nil then
		return entry.trustedOverride[1]
	end

	-- GetJoinData can throw (and does for a non-Player stand-in in tests); treat any failure as "no
	-- trusted band" rather than letting it break the seal.
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if ok and type(joinData) == "table" then
		return joinData.TeleportData
	end
	return nil
end

function TeleportDataService._onReplicated(self: TeleportDataService, player: Player, raw: any)
	if raw ~= nil and type(raw) ~= "table" then
		return -- Malformed payload; ignore rather than seal with garbage.
	end

	local entry = self:_getEntry(player)
	entry.resolve(raw)
end

function TeleportDataService._getEntry(self: TeleportDataService, player: Player): ArrivalEntry
	local existing = self._entries[player]
	if existing then
		return existing
	end

	local maid = Maid.new()
	local promise = Promise.new()

	local entry: ArrivalEntry = {
		maid = maid,
		promise = promise,
		sealed = false,
		trustedOverride = nil,
		trustedRaw = nil,
		nonTrustedRaw = nil,
		read = false,
		resolve = function() end,
	}

	entry.resolve = function(nonTrustedRaw: any)
		if entry.sealed then
			return
		end
		entry.sealed = true
		entry.nonTrustedRaw = nonTrustedRaw
		-- Snapshot the trusted band at the same instant, so every reader sees one frozen pair of bands.
		entry.trustedRaw = self:_getTrustedRaw(player)
		promise:Resolve()
	end

	-- Arm the fallback: if the client never replicates, resolve to the trusted band alone. A
	-- [PlayerMock] has no client, so nothing can replicate asynchronously -- its only "replication"
	-- is a test injection from the running thread. Its fallback therefore fires at the next
	-- resumption step (inject before yielding) instead of stalling every read on the production
	-- window. An explicit SetReplicationTimeoutForTesting keeps the timed fallback, so the timeout
	-- path itself stays drivable from a spec.
	if PlayerMock.isMock(player) and self._replicationTimeout == DEFAULT_REPLICATION_TIMEOUT then
		maid:GiveTask(task.defer(function()
			entry.resolve(nil)
		end))
	else
		maid:GiveTask(task.delay(self._replicationTimeout, function()
			entry.resolve(nil)
		end))
	end

	-- If the player leaves before replicating, seal on what we have so no read hangs forever.
	maid:GiveTask(function()
		entry.resolve(nil)
	end)

	self._entries[player] = entry
	return entry
end

function TeleportDataService._cleanupPlayer(self: TeleportDataService, player: Player)
	local entry = self._entries[player]
	if not entry then
		return
	end

	self._entries[player] = nil
	entry.maid:DoCleaning()
end

function TeleportDataService.Destroy(self: TeleportDataService)
	self._maid:Destroy()
end

return TeleportDataService
