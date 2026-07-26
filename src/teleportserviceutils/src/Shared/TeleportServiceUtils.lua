--!strict
--[=[
	Utilities for teleporting players, including mock-aware wrappers of the TeleportService teleport
	APIs. A [PlayerMock] records its teleports in the `"TeleportService.Teleport"` lookup domain, keyed
	by destination placeId, instead of reaching the engine:

	```lua
	TeleportServiceUtils.teleport(placeId, mock, { SlotId = "abc" })
	local hop = PlayerMock.readLookup(mock, "TeleportService.Teleport", placeId)
	```

	A refusal comes from the `"TeleportService.TeleportInitFailed"` lookup the same way.

	@class TeleportServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TeleportService = game:GetService("TeleportService")

local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

-- Roblox refuses teleports for transient reasons, so the default is patient.
local DEFAULT_MAX_ATTEMPTS = 5
local DEFAULT_RETRY_WAIT = 10

local TeleportServiceUtils = {}

--[=[
	A teleport recorded against a [PlayerMock]. `via` names the TeleportService API the caller reached
	for.

	@type MockTeleport { via: string, teleportData: { [string]: any }?, instanceId: string?, spawnName: string? }
	@within TeleportServiceUtils
]=]
export type MockTeleport = {
	via: string,
	teleportData: { [string]: any }?,
	instanceId: string?,
	spawnName: string?,
}

--[=[
	How a client teleport retries when the engine refuses it (see
	[TeleportServiceUtils.promiseTeleportClient]). `maxAttempts = 1` means no retry at all.

	@type TeleportClientConfig { teleportData: { [string]: any }?, maxAttempts: number?, retryWait: number? }
	@within TeleportServiceUtils
]=]
export type TeleportClientConfig = {
	teleportData: { [string]: any }?,
	maxAttempts: number?,
	retryWait: number?,
}

local function recordMockTeleport(player: Player, placeId: number, record: MockTeleport): ()
	PlayerMock.writeLookup(player, "TeleportService.Teleport", placeId, record)
end

local function connectTeleportInitFailed(
	placeId: number,
	player: Player,
	onFailed: (message: string) -> ()
): RBXScriptConnection
	if PlayerMock.isMock(player) then
		return PlayerMock.getLookupChangedSignal(player, "TeleportService.TeleportInitFailed", placeId)
			:Connect(function()
				local failure = PlayerMock.readLookup(player, "TeleportService.TeleportInitFailed", placeId)
				if failure == nil then
					return
				end

				onFailed(failure.message)
			end)
	end

	return TeleportService.TeleportInitFailed:Connect(function(failedPlayer: Player, _result, message: string)
		if failedPlayer ~= player then
			return
		end

		onFailed(message)
	end)
end

--[=[
	Mock-aware `TeleportService:Teleport(placeId, player, teleportData)`. On a server prefer
	[TeleportServiceUtils.teleportAsync]; on a client this is the teleport, since TeleportAsync is
	server-only.

	@param placeId number
	@param player Player -- a real Player or a PlayerMock
	@param teleportData { [string]: any }?
	@return boolean -- Whether the teleport was started.
	@return string? -- Why the engine refused it, when it did.
]=]
function TeleportServiceUtils.teleport(
	placeId: number,
	player: Player,
	teleportData: { [string]: any }?
): (boolean, string?)
	assert(type(placeId) == "number", "Bad placeId")
	assert(player, "No player")

	if PlayerMock.isMock(player) then
		recordMockTeleport(player, placeId, { via = "Teleport", teleportData = teleportData or {} })
		return true
	end

	local ok, err = pcall(function()
		TeleportService:Teleport(placeId, player, teleportData)
	end)
	if not ok then
		return false, tostring(err)
	end

	return true
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

	@server
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

--[=[
	A client teleporting itself through [TeleportServiceUtils.teleport], retried while the engine
	refuses the hop.

	The promise reports only failure: a teleport that works ends with the player leaving this place, so
	it stays pending until the client is gone. Destroying it stops the retries and rejects with nothing,
	so a caller can tell its own teardown from a hop that genuinely failed.

	```lua
	maid._teleport = TeleportServiceUtils.promiseTeleportClient(placeId, Players.LocalPlayer, {
		teleportData = teleportData,
	}):Catch(function(err)
		-- retries spent; the player is going nowhere
	end)
	```

	@client
	@param placeId number
	@param player Player -- the local player, or a PlayerMock standing in for one
	@param config TeleportClientConfig?
	@return Promise<()> -- Pending while in flight; rejects with the reason when the attempts are spent.
]=]
function TeleportServiceUtils.promiseTeleportClient(
	placeId: number,
	player: Player,
	config: TeleportClientConfig?
): Promise.Promise<()>
	assert(type(placeId) == "number", "Bad placeId")
	assert(player, "No player")
	assert(config == nil or type(config) == "table", "Bad config")

	local teleportData = config and config.teleportData
	local maxAttempts = (config and config.maxAttempts) or DEFAULT_MAX_ATTEMPTS
	local retryWait = (config and config.retryWait) or DEFAULT_RETRY_WAIT

	assert(teleportData == nil or type(teleportData) == "table", "Bad config.teleportData")
	assert(type(maxAttempts) == "number" and maxAttempts >= 1, "Bad config.maxAttempts")
	assert(type(retryWait) == "number" and retryWait >= 0, "Bad config.retryWait")

	local promise = Promise.new()

	local maid = Maid.new()
	promise:Finally(function()
		maid:DoCleaning()
	end)

	local attempt: () -> ()

	local attempts = 0
	local reportedAttempts = 0

	local function onFailed(message: string)
		if not promise:IsPending() then
			return
		end

		-- A refused hop reports itself twice: the call raises and TeleportInitFailed fires.
		if reportedAttempts >= attempts then
			return
		end
		reportedAttempts = attempts

		if attempts >= maxAttempts then
			promise:Reject(`Teleport to place {placeId} failed after {attempts} attempt(s): {message}`)
			return
		end

		-- Cancelling the backoff destroys the promise but cannot unschedule the delay itself.
		local retry
		retry = Promise.delay(retryWait, function(resolve)
			if retry:IsPending() then
				attempt()
			end

			resolve()
		end)

		maid._retry = retry
	end

	function attempt()
		attempts += 1

		local ok, err = TeleportServiceUtils.teleport(placeId, player, teleportData)
		if not ok then
			onFailed(err or "Teleport failed")
		end
	end

	maid:GiveTask(connectTeleportInitFailed(placeId, player, onFailed))

	attempt()

	return promise
end

return TeleportServiceUtils
