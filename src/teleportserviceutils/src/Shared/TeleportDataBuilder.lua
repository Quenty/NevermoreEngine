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

local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

--[=[
	Contributes teleport data shared by *every* player in a teleport. Returns nil to contribute nothing.

	@type TeleportDataProvider ({ Player }) -> ({ [string]: any }?)
	@within TeleportDataBuilder
]=]
export type TeleportDataProvider = ({ Player }) -> { [string]: any }? | Promise.Promise<{ [string]: any }?>

--[=[
	Contributes teleport data for a *single* player in a teleport (called once per player, with the full
	player list for context). Returns nil to contribute nothing. This is how per-player data survives a
	group teleport, where every player would otherwise share one flat table.

	@type PerPlayerTeleportDataProvider (Player, { Player }) -> ({ [string]: any }?)
	@within TeleportDataBuilder
]=]
export type PerPlayerTeleportDataProvider = (
	Player,
	{ Player }
) -> { [string]: any }? | Promise.Promise<{ [string]: any }?>

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

-- Merges already-resolved provider contributions (plain tables; nil/non-table/Promise entries are
-- skipped) into the per-player envelope, applying precedence (shared providers, then baseData, then
-- per-player) and the size guard. Shared by the sync and async build paths so both produce an
-- identical envelope.
function TeleportDataBuilder._assembleEnvelope(
	self: TeleportDataBuilder,
	sharedContributions: { any },
	perPlayerContributions: { { player: Player, contributions: { any } } },
	baseData: { [string]: any }?
): { [string]: any }
	local function mergeInto(target: { [string]: any }, contributed: any)
		-- A Promise is itself a table, so guard against merging an un-awaited one into the envelope.
		if type(contributed) == "table" and not Promise.isPromise(contributed) then
			for key, value in contributed do
				target[key] = value
			end
		end
	end

	local sharedSlice: { [string]: any } = {}
	for _, contributed in sharedContributions do
		mergeInto(sharedSlice, contributed)
	end
	if baseData ~= nil then
		for key, value in baseData do
			sharedSlice[key] = value
		end
	end

	local perPlayerByUserId: { [string]: { [string]: any } } = {}
	for _, entry in perPlayerContributions do
		local slice: { [string]: any } = {}
		for _, contributed in entry.contributions do
			mergeInto(slice, contributed)
		end

		if next(slice) ~= nil then
			perPlayerByUserId[tostring(self._getUserId(entry.player))] = slice
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
				#perPlayerContributions
			)
		)
	elseif classification.level == "warn" then
		warn(
			string.format(
				"[TeleportDataBuilder] teleport data is %d bytes, approaching the %d byte cap for %d player(s)",
				classification.bytes,
				TeleportDataEnvelopeUtils.MAX_TELEPORT_DATA_BYTES,
				#perPlayerContributions
			)
		)
	end

	return envelope
end

--[=[
	Builds the teleport-data envelope synchronously (see [TeleportDataBuilder._assembleEnvelope] for the
	precedence and size guard). A provider that returns a Promise cannot be awaited here and contributes
	nothing; use [TeleportDataBuilder.PromiseBuildTeleportData] when any provider is asynchronous.

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

	local sharedContributions = {}
	for _, provider in self._providers do
		local contributed = provider(players)
		if contributed ~= nil then
			table.insert(sharedContributions, contributed)
		end
	end

	local perPlayerContributions = {}
	for _, player in players do
		local contributions = {}
		for _, provider in self._perPlayerProviders do
			local contributed = provider(player, players)
			if contributed ~= nil then
				table.insert(contributions, contributed)
			end
		end
		table.insert(perPlayerContributions, { player = player, contributions = contributions })
	end

	return self:_assembleEnvelope(sharedContributions, perPlayerContributions, baseData)
end

--[=[
	Builds the teleport-data envelope, awaiting any provider that returns a Promise. Providers may return
	a table, nil, or a Promise of either; sync providers behave exactly as in
	[TeleportDataBuilder.BuildTeleportData]. Resolves to the same envelope shape.

	A provider whose Promise rejects rejects the whole build, so an asynchronous provider should handle
	its own errors (e.g. resolve nil) when it would rather degrade than block the teleport.

	@param players { Player }
	@param baseData { [string]: any }?
	@return Promise<{ [string]: any }>
]=]
function TeleportDataBuilder.PromiseBuildTeleportData(
	self: TeleportDataBuilder,
	players: { Player },
	baseData: { [string]: any }?
): Promise.Promise<{ [string]: any }>
	assert(type(players) == "table", "Bad players")
	if baseData ~= nil then
		assert(type(baseData) == "table", "Bad baseData")
	end

	-- Normalize a provider's return (table, nil, or a Promise of either) to a Promise of a non-nil
	-- value: the first Then flattens a returned Promise; the second collapses nil to `false` so
	-- PromiseUtils.all yields a hole-free array (a nil array slot truncates iteration in _assembleEnvelope).
	local function promiseContribution(contributed: any): Promise.Promise<any>
		return Promise.resolved()
			:Then(function()
				return contributed
			end)
			:Then(function(resolved: any)
				if resolved == nil then
					return false
				end
				return resolved
			end)
	end

	-- PromiseUtils.all resolves a *tuple* (and special-cases 0- and 1-element lists), so pack the
	-- varargs into one array value: every downstream Then then receives a single, uniformly-shaped array.
	local function promiseContributionArray(contributionPromises: { any }): Promise.Promise<{ any }>
		return PromiseUtils.all(contributionPromises):Then(function(...)
			return { ... }
		end)
	end

	local sharedContributionPromises = {}
	for _, provider in self._providers do
		table.insert(sharedContributionPromises, promiseContribution(provider(players)))
	end

	local perPlayerListPromises = {}
	for _, player in players do
		local contributionPromises = {}
		for _, provider in self._perPlayerProviders do
			table.insert(contributionPromises, promiseContribution(provider(player, players)))
		end
		table.insert(perPlayerListPromises, promiseContributionArray(contributionPromises))
	end

	return promiseContributionArray(sharedContributionPromises):Then(function(sharedContributions)
		return promiseContributionArray(perPlayerListPromises):Then(function(perPlayerLists)
			local perPlayerContributions = {}
			for index, player in players do
				table.insert(perPlayerContributions, {
					player = player,
					contributions = perPlayerLists[index],
				})
			end
			return self:_assembleEnvelope(sharedContributions, perPlayerContributions, baseData)
		end)
	end)
end

return TeleportDataBuilder
