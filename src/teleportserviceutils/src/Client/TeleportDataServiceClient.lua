--!strict
--[=[
	Client half of [TeleportDataService]: reads the teleport data the local player arrived with
	(`TeleportService:GetLocalPlayerTeleportData()`), so client systems query arrived values through
	one place instead of touching [TeleportService] directly.

	@client
	@class TeleportDataServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")

local TeleportDataServiceClient = {}
TeleportDataServiceClient.ServiceName = "TeleportDataServiceClient"

export type TeleportDataServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		-- The raw arrived table (envelope or legacy flat), captured before unwrapping. Kept raw rather
		-- than pre-sliced so the slice can be re-derived and the test seam injects what actually arrived.
		_arrivedRaw: { [string]: any }?,
		-- Arrived data is captured lazily on first read (not at Init) so a test can inject an override
		-- before anything consumes it; `_arrivedRead` lets the test seam assert it did so in time.
		_arrivedResolved: boolean,
		_arrivedRead: boolean,
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

	self._arrivedRaw = nil
	self._arrivedResolved = false
	self._arrivedRead = false
end

--[=[
	Returns the teleport data the local player arrived with, or nil. The raw table is resolved once
	(from the real teleport data, or a test override) and cached for the life of the session; an
	envelope is unwrapped to the local player's slice on read, mirroring the server's
	[TeleportDataService.GetArrivedTeleportData].

	@return { [string]: any }?
]=]
function TeleportDataServiceClient.GetArrivedTeleportData(self: TeleportDataServiceClient): { [string]: any }?
	if not self._arrivedResolved then
		self._arrivedRaw = readLocalPlayerTeleportData()
		self._arrivedResolved = true
	end

	self._arrivedRead = true

	local raw = self._arrivedRaw
	if type(raw) ~= "table" then
		return nil
	end

	-- Legacy/hand-written flat data is read as-is; only an envelope is unwrapped to this player's
	-- slice, which is why the UserId read is deferred to here (a headless client has no LocalPlayer).
	if not TeleportDataEnvelopeUtils.isEnvelope(raw) then
		return raw :: { [string]: any }
	end

	return TeleportDataEnvelopeUtils.readSlice(raw, self:_getLocalUserId())
end

--[=[
	Resolves the UserId used to select the local player's envelope slice. A method so tests can stand
	in a fixed id (a headless client has no `Players.LocalPlayer`), mirroring the server's
	`_getUserId` seam.

	@return number
]=]
function TeleportDataServiceClient._getLocalUserId(_self: TeleportDataServiceClient): number
	return Players.LocalPlayer.UserId
end

--[=[
	Returns the value the local player arrived with under `key`, or nil.

	@param key string
	@return any
]=]
function TeleportDataServiceClient.GetArrivedValue(self: TeleportDataServiceClient, key: string): any
	assert(type(key) == "string", "Bad key")

	local data = self:GetArrivedTeleportData()
	if type(data) == "table" then
		return data[key]
	end

	return nil
end

--[=[
	Returns whether the local player arrived with a value under `key`.

	@param key string
	@return boolean
]=]
function TeleportDataServiceClient.HasArrivedValue(self: TeleportDataServiceClient, key: string): boolean
	return self:GetArrivedValue(key) ~= nil
end

--[=[
	Overrides the arrived teleport data. Test seam -- headless test clients have no real teleport
	data, so specs inject what the local player would have arrived with. Must be called before
	anything reads the arrived data, so the override is what every reader sees.

	@param data { [string]: any }?
]=]
function TeleportDataServiceClient.SetArrivedTeleportDataForTesting(
	self: TeleportDataServiceClient,
	data: { [string]: any }?
)
	assert(
		not self._arrivedRead,
		"Cannot set arrived teleport data after it has been read -- inject it before anything reads it"
	)

	self._arrivedRaw = data
	self._arrivedResolved = true
end

function TeleportDataServiceClient.Destroy(self: TeleportDataServiceClient)
	self._maid:Destroy()
end

return TeleportDataServiceClient
