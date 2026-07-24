--!strict
--[=[
	Utilities for teleporting players, including mock-aware wrappers of the user-facing TeleportService
	teleport APIs. With a [PlayerMock] (a headless test), each teleport is recorded on the mock -- the
	`"TeleportService.Teleport"` lookup domain, keyed by destination placeId -- instead of calling the
	engine, which rejects a mock and would surface as a `TeleportInitFailed`. A test reads the recorded
	teleport back to assert the hop and the data carried with it:

	```lua
	TeleportServiceUtils.teleport(placeId, mock, { SlotId = "abc" })
	local hop = PlayerMock.readLookup(mock, "TeleportService.Teleport", placeId)
	-- hop.via == "Teleport", hop.teleportData.SlotId == "abc"
	```

	@class TeleportServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TeleportService = game:GetService("TeleportService")

local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

local TeleportServiceUtils = {}

--[=[
	A teleport recorded against a [PlayerMock] (stored in the `"TeleportService.Teleport"` lookup domain
	keyed by destination placeId). `via` names the TeleportService API the caller reached for.

	@type MockTeleport { via: string, teleportData: { [string]: any }?, instanceId: string?, spawnName: string? }
	@within TeleportServiceUtils
]=]
export type MockTeleport = {
	via: string,
	teleportData: { [string]: any }?,
	instanceId: string?,
	spawnName: string?,
}

local function recordMockTeleport(player: Player, placeId: number, record: MockTeleport): ()
	PlayerMock.writeLookup(player, "TeleportService.Teleport", placeId, record)
end

--[=[
	Mock-aware `TeleportService:Teleport(placeId, player, teleportData)`.
	@param placeId number
	@param player Player -- a real Player or a PlayerMock
	@param teleportData { [string]: any }?
]=]
function TeleportServiceUtils.teleport(placeId: number, player: Player, teleportData: { [string]: any }?): ()
	assert(type(placeId) == "number", "Bad placeId")
	assert(player, "No player")

	if PlayerMock.isMock(player) then
		recordMockTeleport(player, placeId, { via = "Teleport", teleportData = teleportData or {} })
		return
	end

	TeleportService:Teleport(placeId, player, teleportData)
end

--[=[
	Mock-aware `TeleportService:TeleportToPlaceInstance(placeId, instanceId, player, spawnName, teleportData)`,
	which sends a player to one specific running server (e.g. joining a friend).
	@param placeId number
	@param instanceId string -- the destination job/server id
	@param player Player
	@param spawnName string?
	@param teleportData { [string]: any }?
]=]
function TeleportServiceUtils.teleportToPlaceInstance(
	placeId: number,
	instanceId: string,
	player: Player,
	spawnName: string?,
	teleportData: { [string]: any }?
): ()
	assert(type(placeId) == "number", "Bad placeId")
	assert(type(instanceId) == "string", "Bad instanceId")
	assert(player, "No player")

	if PlayerMock.isMock(player) then
		recordMockTeleport(player, placeId, {
			via = "TeleportToPlaceInstance",
			teleportData = teleportData or {},
			instanceId = instanceId,
			spawnName = spawnName,
		})
		return
	end

	TeleportService:TeleportToPlaceInstance(placeId, instanceId, player, spawnName, teleportData)
end

--[=[
	Mock-aware `TeleportService:TeleportAsync(placeId, players, teleportOptions)`. Mock players in the
	batch are recorded (with the options' teleport data) and dropped from the engine call; a batch of
	only mocks skips the engine and returns nil. Real players teleport and the TeleportAsyncResult is
	returned.
	@param placeId number
	@param players { Player }
	@param teleportOptions TeleportOptions?
	@return TeleportAsyncResult?
]=]
function TeleportServiceUtils.teleportAsync(
	placeId: number,
	players: { Player },
	teleportOptions: TeleportOptions?
): TeleportAsyncResult?
	assert(type(placeId) == "number", "Bad placeId")
	assert(type(players) == "table", "Bad players")
	assert(
		teleportOptions == nil or (typeof(teleportOptions) == "Instance" and teleportOptions:IsA("TeleportOptions")),
		"Bad teleportOptions"
	)

	local teleportData: { [string]: any }? = if teleportOptions then teleportOptions:GetTeleportData() :: any else nil

	local realPlayers: { Player } = {}
	for _, player in players do
		if PlayerMock.isMock(player) then
			recordMockTeleport(player, placeId, { via = "TeleportAsync", teleportData = teleportData })
		else
			table.insert(realPlayers, player)
		end
	end

	if #realPlayers == 0 then
		return nil
	end

	return TeleportService:TeleportAsync(placeId, realPlayers, teleportOptions)
end

--[=[
	Wraps TeleportService:ReserveServer(placeId)
	@param placeId number
	@return Promise<string> -- Code
]=]
function TeleportServiceUtils.promiseReserveServer(placeId: number): Promise.Promise<string>
	assert(type(placeId) == "number", "Bad placeId")

	return Promise.spawn(function(resolve, reject)
		local accessCode
		local ok, err = pcall(function()
			accessCode = TeleportService:ReserveServer(placeId)
		end)
		if not ok then
			return reject(err)
		end

		return resolve(accessCode)
	end)
end

--[=[
	Promise wrapper of [TeleportServiceUtils.teleportAsync] -- so it is mock-aware too, recording mock
	players and resolving without an engine call when the batch is all mocks.
	@param placeId number
	@param players { Player }
	@param teleportOptions TeleportOptions?
	@return Promise<TeleportAsyncResult?>
]=]
function TeleportServiceUtils.promiseTeleport(
	placeId: number,
	players: { Player },
	teleportOptions: TeleportOptions?
): Promise.Promise<TeleportAsyncResult?>
	assert(type(placeId) == "number", "Bad placeId")
	assert(type(players) == "table", "Bad players")
	assert(
		typeof(teleportOptions) == "Instance" and teleportOptions:IsA("TeleportOptions") or teleportOptions == nil,
		"Bad options"
	)

	return Promise.spawn(function(resolve, reject)
		local teleportAsyncResult
		local ok, err = pcall(function()
			teleportAsyncResult = TeleportServiceUtils.teleportAsync(placeId, players, teleportOptions)
		end)
		if not ok then
			return reject(err)
		end

		return resolve(teleportAsyncResult)
	end)
end

return TeleportServiceUtils
