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

--[=[
	Contributes a slice of teleport data for a teleport of the given players. Returns nil to
	contribute nothing.

	@type TeleportDataProvider ({ Player }) -> ({ [string]: any }?)
	@within TeleportDataService
]=]
export type TeleportDataProvider = ({ Player }) -> { [string]: any }?

local TeleportDataService = {}
TeleportDataService.ServiceName = "TeleportDataService"

export type TeleportDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_providers: { TeleportDataProvider },
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
	Builds the merged teleport data for a teleport of the given players: every registered provider's
	contribution merged together, with `baseData` overlaid last so caller-supplied keys always win.

	Pure -- performs no teleport -- so it is the seam teleport sites and tests build against.

	@param players { Player }
	@param baseData { [string]: any }? -- caller keys, applied last (win on conflict)
	@return { [string]: any }
]=]
function TeleportDataService.BuildTeleportData(
	self: TeleportDataService,
	players: { Player },
	baseData: { [string]: any }?
): { [string]: any }
	assert(type(players) == "table", "Bad players")

	local data: { [string]: any } = {}

	for _, provider in self._providers do
		local contributed = provider(players)
		if type(contributed) == "table" then
			for key, value in contributed do
				data[key] = value
			end
		end
	end

	if baseData ~= nil then
		assert(type(baseData) == "table", "Bad baseData")
		for key, value in baseData do
			data[key] = value
		end
	end

	return data
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

	local override = self._arrivedOverrides[player]
	if override ~= nil then
		return override[1]
	end

	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) == "table" then
		return teleportData :: { [string]: any }
	end

	return nil
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
