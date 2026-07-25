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

	The refusal side is mocked the same way: since the engine never sees a mock's teleport it can never
	refuse one, so [TeleportServiceUtils.promiseTeleportClient] takes its `TeleportInitFailed` from the
	`"TeleportService.TeleportInitFailed"` lookup a test writes.

	@class TeleportServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TeleportService = game:GetService("TeleportService")

local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

-- What a client teleport does when the engine refuses it, unless the caller says otherwise. Roblox
-- refuses a teleport for transient reasons (a full destination server, a place still deploying), so
-- the default is patient: five attempts a wide ten seconds apart.
local DEFAULT_MAX_ATTEMPTS = 5
local DEFAULT_RETRY_WAIT = 10

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

--[=[
	How a client teleport retries when the engine refuses it (see
	[TeleportServiceUtils.promiseTeleportClient]). Every field is optional; an omitted one takes the
	default, and `maxAttempts = 1` means a single try with no retry at all.

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
					return -- Cleared back to "nothing refused", which is not itself a refusal.
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
	A client teleporting itself, retried while the engine refuses the hop.

	The promise reports only failure. A teleport that works ends with the player leaving this place, so
	the success case never settles -- it stays pending until the client is gone. It rejects with the
	reason once the attempts are spent, which is the caller's cue to take the terminal path: the player
	is stranded here otherwise. Destroying it (a maid slot cleaning up) stops the retries and rejects
	with nothing, so a caller can tell its own teardown from a hop that genuinely failed.

	```lua
	maid._teleport = TeleportServiceUtils.promiseTeleportClient(placeId, Players.LocalPlayer, {
		teleportData = teleportData,
	}):Catch(function(err)
		-- retries spent; the player is going nowhere
	end)
	```

	Mock-aware throughout (see [TeleportServiceUtils.teleport]): the hop is recorded on a
	[PlayerMock] rather than run by the engine, and a refusal is whatever the test injects into the
	`"TeleportService.TeleportInitFailed"` lookup.

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

	-- Everything the attempt sets up hangs off the promise's own lifetime, so the retry connection and
	-- any pending backoff go away the moment it settles or is cancelled.
	local maid = Maid.new()
	promise:Finally(function()
		maid:DoCleaning()
	end)

	local attempts = 0
	local function attempt()
		attempts += 1
		TeleportServiceUtils.teleport(placeId, player, teleportData)
	end

	maid:GiveTask(connectTeleportInitFailed(placeId, player, function(message: string)
		if not promise:IsPending() then
			return
		end

		if attempts >= maxAttempts then
			promise:Reject(`Teleport to place {placeId} failed after {attempts} attempt(s): {message}`)
			return
		end

		-- Backoff as a promise rather than a yield in the signal handler, so the wait between attempts
		-- is a maid task that cancellation can reach. Reaching it destroys the promise but cannot
		-- unschedule the delay itself, so the attempt is what checks: a backoff that was cancelled --
		-- by teardown, or by a later refusal replacing it -- must not teleport anyone.
		local retry
		retry = Promise.delay(retryWait, function(resolve)
			if retry:IsPending() then
				attempt()
			end

			resolve()
		end)

		maid._retry = retry
	end))

	attempt()

	return promise
end

return TeleportServiceUtils
