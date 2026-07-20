--!strict
--[=[
	Central place to assemble the [TeleportData] a teleport should carry. Systems register a
	provider once (analytics, save-slot id, ...) and every teleport site builds its data through
	[TeleportDataService.BuildTeleportData] instead of hand-writing the same table -- so a site can
	never forget to attach the shared data, and the assembly is unit testable.

	This service only *builds* data and *reads* the data a player arrived with; it deliberately does
	not wrap the teleport call itself (that stays on [TeleportServiceUtils]), so we are never forced
	to route every teleport through here.

	@server
	@class TeleportDataService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

--[=[
	Contributes teleport data shared by *every* player in a teleport. Returns nil to contribute
	nothing.

	@type TeleportDataProvider ({ Player }) -> ({ [string]: any }?)
	@within TeleportDataService
]=]
export type TeleportDataProvider = ({ Player }) -> { [string]: any }?

--[=[
	Contributes teleport data for a *single* player in a teleport (called once per player, with the
	full player list for context). Returns nil to contribute nothing. This is how per-player data
	survives a group teleport, where every player would otherwise share one flat table.

	@type PerPlayerTeleportDataProvider (Player, { Player }) -> ({ [string]: any }?)
	@within TeleportDataService
]=]
export type PerPlayerTeleportDataProvider = (Player, { Player }) -> { [string]: any }?

local TeleportDataService = {}
TeleportDataService.ServiceName = "TeleportDataService"

export type TeleportDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_providers: { TeleportDataProvider },
		_perPlayerProviders: { PerPlayerTeleportDataProvider },
		-- Boxed ({ data } where data may be nil) so an injected nil override is distinguishable from
		-- "no override" and does not fall through to GetJoinData.
		_arrivedOverrides: { [Player]: { { [string]: any }? } },
		-- Players whose arrived data has already been read. Injecting a test override after a read
		-- would silently disagree with what the earlier reader saw, so the seam asserts against it.
		_arrivedRead: { [Player]: true },
	},
	{} :: typeof({ __index = TeleportDataService })
))

function TeleportDataService.Init(self: TeleportDataService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._providers = {}
	self._perPlayerProviders = {}
	self._arrivedOverrides = {}
	self._arrivedRead = {}
end

--[=[
	Registers a provider that contributes teleport data on every [TeleportDataService.BuildTeleportData]
	call. Returns a function that unregisters the provider (also give it to a [Maid]).

	@param provider TeleportDataProvider
	@return () -> ()
]=]
function TeleportDataService.RegisterTeleportDataProvider(
	self: TeleportDataService,
	provider: TeleportDataProvider
): () -> ()
	assert(type(provider) == "function", "Bad provider")

	table.insert(self._providers, provider)

	return function()
		local index = table.find(self._providers, provider)
		if index then
			table.remove(self._providers, index)
		end
	end
end

--[=[
	Registers a per-player provider that contributes each player's own slice on every
	[TeleportDataService.BuildTeleportData] call. Returns a function that unregisters it (also give it
	to a [Maid]).

	@param provider PerPlayerTeleportDataProvider
	@return () -> ()
]=]
function TeleportDataService.RegisterPerPlayerTeleportDataProvider(
	self: TeleportDataService,
	provider: PerPlayerTeleportDataProvider
): () -> ()
	assert(type(provider) == "function", "Bad provider")

	table.insert(self._perPlayerProviders, provider)

	return function()
		local index = table.find(self._perPlayerProviders, provider)
		if index then
			table.remove(self._perPlayerProviders, index)
		end
	end
end

--[=[
	Builds the teleport data for a teleport of the given players as a per-player envelope (see
	[TeleportDataEnvelopeUtils]): shared-provider contributions plus `baseData` form the shared slice,
	and each per-player provider's contribution forms that player's slice. On arrival each player reads
	their own slice merged over the shared one via [TeleportDataService.GetArrivedTeleportData].

	Precedence, least to most specific: shared providers, then `baseData` (the caller's shared
	override), then per-player providers.

	Pure -- performs no teleport -- so it is the seam teleport sites and tests build against. Errors if
	the result exceeds the teleport-data size cap, and warns as it approaches it, so an oversized
	payload fails loudly here instead of being silently dropped by the teleport.

	@param players { Player }
	@param baseData { [string]: any }? -- shared caller keys, overriding shared providers
	@return { [string]: any }
]=]
function TeleportDataService.BuildTeleportData(
	self: TeleportDataService,
	players: { Player },
	baseData: { [string]: any }?
): { [string]: any }
	assert(type(players) == "table", "Bad players")
	if baseData ~= nil then
		assert(type(baseData) == "table", "Bad baseData")
	end

	local sharedSlice: { [string]: any } = {}
	for _, provider in self._providers do
		local contributed = provider(players)
		if type(contributed) == "table" then
			for key, value in contributed do
				sharedSlice[key] = value
			end
		end
	end
	if baseData ~= nil then
		for key, value in baseData do
			sharedSlice[key] = value
		end
	end

	local perPlayerByUserId: { [string]: { [string]: any } } = {}
	for _, player in players do
		local slice: { [string]: any } = {}
		for _, provider in self._perPlayerProviders do
			local contributed = provider(player, players)
			if type(contributed) == "table" then
				for key, value in contributed do
					slice[key] = value
				end
			end
		end

		if next(slice) ~= nil then
			perPlayerByUserId[tostring(self:_getUserId(player))] = slice
		end
	end

	local envelope = TeleportDataEnvelopeUtils.build(sharedSlice, perPlayerByUserId)

	local classification = TeleportDataEnvelopeUtils.classifySize(envelope)
	if classification.level == "over" then
		error(
			string.format(
				"[TeleportDataService] teleport data is %d bytes, over the %d byte cap for %d player(s); reduce provider payloads",
				classification.bytes,
				TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES,
				#players
			)
		)
	elseif classification.level == "warn" then
		warn(
			string.format(
				"[TeleportDataService] teleport data is %d bytes, approaching the %d byte cap for %d player(s)",
				classification.bytes,
				TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES,
				#players
			)
		)
	end

	return envelope
end

--[=[
	Returns the teleport data the player arrived with (from `player:GetJoinData().TeleportData`), or
	the value injected by [TeleportDataService.SetArrivedTeleportDataForTesting].

	@param player Player
	@return { [string]: any }?
]=]
function TeleportDataService.GetArrivedTeleportData(self: TeleportDataService, player: Player): { [string]: any }?
	assert(typeof(player) == "Instance", "Bad player")

	self._arrivedRead[player] = true

	local raw: any
	local override = self._arrivedOverrides[player]
	if override ~= nil then
		raw = override[1]
	else
		local joinData = player:GetJoinData()
		raw = joinData and joinData.TeleportData
	end

	if type(raw) ~= "table" then
		return nil
	end

	-- Legacy/hand-written flat data is read as-is (no UserId needed); only an envelope is unwrapped to
	-- this player's slice, which is why the UserId read is deferred to here.
	if not TeleportDataEnvelopeUtils.isEnvelope(raw) then
		return raw :: { [string]: any }
	end

	return TeleportDataEnvelopeUtils.readSlice(raw, self:_getUserId(player))
end

--[=[
	Resolves the UserId used to key a player's envelope slice. A method so tests can stand in a fake
	player (which has no UserId) by overriding it.

	@param player Player
	@return number
]=]
function TeleportDataService._getUserId(_self: TeleportDataService, player: Player): number
	return player.UserId
end

--[=[
	Returns the value the player arrived with under `key`, or nil.

	@param player Player
	@param key string
	@return any
]=]
function TeleportDataService.GetArrivedValue(self: TeleportDataService, player: Player, key: string): any
	assert(type(key) == "string", "Bad key")

	local data = self:GetArrivedTeleportData(player)
	if type(data) == "table" then
		return data[key]
	end

	return nil
end

--[=[
	Returns whether the player arrived with a value under `key`.

	@param player Player
	@param key string
	@return boolean
]=]
function TeleportDataService.HasArrivedValue(self: TeleportDataService, player: Player, key: string): boolean
	return self:GetArrivedValue(player, key) ~= nil
end

--[=[
	Overrides the arrived teleport data for a player. Test seam -- headless servers have no joined
	players, so specs inject the data a player would have arrived with.

	@param player Player
	@param data { [string]: any }?
]=]
function TeleportDataService.SetArrivedTeleportDataForTesting(
	self: TeleportDataService,
	player: Player,
	data: { [string]: any }?
)
	assert(typeof(player) == "Instance", "Bad player")
	assert(
		not self._arrivedRead[player],
		"Cannot set arrived teleport data after it has been read -- inject it before anything reads it"
	)

	self._arrivedOverrides[player] = { data }
end

function TeleportDataService.Destroy(self: TeleportDataService)
	self._maid:Destroy()
end

return TeleportDataService
