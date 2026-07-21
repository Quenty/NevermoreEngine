--!strict
--[=[
	Realm-agnostic assembly of the teleport-data envelope: the provider registry plus
	[TeleportDataBuilder.BuildTeleportData]. Both [TeleportDataService] (server) and
	[TeleportDataServiceClient] (client) own one of these and delegate their build surface to it, so a
	teleport authored on either realm goes through the *same* providers and produces the *same* envelope
	shape. That symmetry is the point: a client-initiated teleport can no longer forget shared data or
	hand-roll a divergent table.

	Pure -- it performs no teleport and touches no [Player] state beyond the injected UserId resolver --
	so it is unit tested without any real player.

	@class TeleportDataBuilder
]=]

local require = require(script.Parent.loader).load(script)

local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

--[=[
	Contributes teleport data shared by *every* player in a teleport. Returns nil to contribute nothing.

	@type TeleportDataProvider ({ Player }) -> ({ [string]: any }?)
	@within TeleportDataBuilder
]=]
export type TeleportDataProvider = ({ Player }) -> { [string]: any }?

--[=[
	Contributes teleport data for a *single* player in a teleport (called once per player, with the full
	player list for context). Returns nil to contribute nothing. This is how per-player data survives a
	group teleport, where every player would otherwise share one flat table.

	@type PerPlayerTeleportDataProvider (Player, { Player }) -> ({ [string]: any }?)
	@within TeleportDataBuilder
]=]
export type PerPlayerTeleportDataProvider = (Player, { Player }) -> { [string]: any }?

local TeleportDataBuilder = {}
TeleportDataBuilder.ClassName = "TeleportDataBuilder"
TeleportDataBuilder.__index = TeleportDataBuilder

export type TeleportDataBuilder = typeof(setmetatable(
	{} :: {
		_providers: { TeleportDataProvider },
		_perPlayerProviders: { PerPlayerTeleportDataProvider },
		_getUserId: (Player) -> number,
	},
	TeleportDataBuilder
))

--[=[
	Creates a builder. `getUserId` resolves the UserId used to key a player's envelope slice; it is
	injected (rather than reading `player.UserId` directly) so a headless test can stand in a fake player.

	@param getUserId ((Player) -> number)?
	@return TeleportDataBuilder
]=]
function TeleportDataBuilder.new(getUserId: ((Player) -> number)?): TeleportDataBuilder
	local self: TeleportDataBuilder = setmetatable({} :: any, TeleportDataBuilder)

	self._providers = {}
	self._perPlayerProviders = {}
	self._getUserId = getUserId or function(player: Player): number
		return player.UserId
	end

	return self
end

--[=[
	Registers a provider that contributes teleport data on every [TeleportDataBuilder.BuildTeleportData]
	call. Returns a function that unregisters the provider (also give it to a [Maid]).

	@param provider TeleportDataProvider
	@return () -> ()
]=]
function TeleportDataBuilder.RegisterTeleportDataProvider(
	self: TeleportDataBuilder,
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
	[TeleportDataBuilder.BuildTeleportData] call. Returns a function that unregisters it (also give it to
	a [Maid]).

	@param provider PerPlayerTeleportDataProvider
	@return () -> ()
]=]
function TeleportDataBuilder.RegisterPerPlayerTeleportDataProvider(
	self: TeleportDataBuilder,
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
	[TeleportDataEnvelopeUtils]): shared-provider contributions plus `baseData` form the shared slice, and
	each per-player provider's contribution forms that player's slice.

	Precedence, least to most specific: shared providers, then `baseData` (the caller's shared override),
	then per-player providers.

	Errors if the result exceeds the teleport-data size cap, and warns as it approaches it, so an
	oversized payload fails loudly here instead of being silently dropped by the teleport.

	@param players { Player }
	@param baseData { [string]: any }? -- shared caller keys, overriding shared providers
	@return { [string]: any }
]=]
function TeleportDataBuilder.BuildTeleportData(
	self: TeleportDataBuilder,
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
			perPlayerByUserId[tostring(self._getUserId(player))] = slice
		end
	end

	local envelope = TeleportDataEnvelopeUtils.build(sharedSlice, perPlayerByUserId)

	local classification = TeleportDataEnvelopeUtils.classifySize(envelope)
	if classification.level == "over" then
		error(
			string.format(
				"[TeleportDataBuilder] teleport data is %d bytes, over the %d byte cap for %d player(s); reduce provider payloads",
				classification.bytes,
				TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES,
				#players
			)
		)
	elseif classification.level == "warn" then
		warn(
			string.format(
				"[TeleportDataBuilder] teleport data is %d bytes, approaching the %d byte cap for %d player(s)",
				classification.bytes,
				TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES,
				#players
			)
		)
	end

	return envelope
end

return TeleportDataBuilder
