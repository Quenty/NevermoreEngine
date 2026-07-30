--!strict
--[=[
	Utilities for teleporting players, including mock-aware wrappers of the TeleportService teleport
	APIs. A [PlayerMock] records its teleports in the `"TeleportService.Teleport"` lookup domain, keyed
	by destination placeId, instead of reaching the engine:

	```lua
	TeleportServiceUtils.teleport(placeId, mock, { SlotId = "abc" })
	local hop = PlayerMock.readLookup(mock, "TeleportService.Teleport", placeId)
	```

	What the engine would have said back goes in through the `"TeleportService.TeleportInitFailed"`
	lookup the same way, `result` and all:

	```lua
	PlayerMock.writeLookup(mock, "TeleportService.TeleportInitFailed", placeId, {
		result = Enum.TeleportResult.GameFull,
		message = "server full",
	})
	```

	@class TeleportServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")
local PromiseRetryUtils = require("PromiseRetryUtils")
local TeleportFailedReportUtils = require("TeleportFailedReportUtils")

-- Roblox refuses teleports for transient reasons, so the default is patient.
local DEFAULT_MAX_ATTEMPTS = 5
local DEFAULT_RETRY_WAIT = 10

-- Flat by default, matching the fixed wait this retried with before it was built on
-- PromiseRetryUtils. Retries are rare enough now (only three results reach one) that backing off
-- further mostly just holds the player at a loading screen.
local DEFAULT_EXPONENTIAL = 1

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
	What a teleport carries and how it retries when the engine refuses it (see
	[TeleportServiceUtils.promiseTeleport]). `maxAttempts = 1` means no retry at all, and `exponential`
	is the per-attempt backoff multiplier (1 keeps the wait flat).

	`teleportOptions` is the server's extra reach -- reserved servers, a named spawn -- and a server
	call may pass one on its own instead of a config. A client has only `teleportData`, which is read
	back out of the options when a call passes those instead.

	`initFailedGraceSeconds` is how long a *server* attempt keeps listening for a refusal the engine
	raises after it has already accepted the request (see
	[TeleportServiceUtils._promiseTeleportServerAttempt]). Unset -- the default -- resolves on acceptance,
	which is what every server call did before this existed.

	@type TeleportConfig { teleportData: { [string]: any }?, teleportOptions: TeleportOptions?, maxAttempts: number?, retryWait: number?, exponential: number?, printWarning: boolean?, initFailedGraceSeconds: number? }
	@within TeleportServiceUtils
]=]
export type TeleportConfig = {
	teleportData: { [string]: any }?,
	teleportOptions: TeleportOptions?,
	maxAttempts: number?,
	retryWait: number?,
	exponential: number?,
	printWarning: boolean?,
	initFailedGraceSeconds: number?,
}

--[=[
	[TeleportConfig] under the name it had while only a client retried.

	@type TeleportClientConfig TeleportConfig
	@within TeleportServiceUtils
]=]
export type TeleportClientConfig = TeleportConfig

--[=[
	Mock-aware `TeleportService:Teleport(placeId, player, teleportData)`, yielded out of
	[TeleportServiceUtils.promiseTeleport] -- so it retries like every other teleport now, and answers
	whether the player is going anywhere rather than only whether the call was made.

	A client teleport that works ends with the player gone, so on the happy path this never returns:
	there is nothing left to return to. It comes back only when the teleport has failed, which is what
	makes the answer worth having.

	@client
	@param placeId number
	@param player Player -- the local player, or a PlayerMock standing in for one
	@param teleportData { [string]: any }?
	@return boolean -- Whether the teleport was started.
	@return string? -- Why the engine refused it, when it did.
]=]
function TeleportServiceUtils.teleport(
	placeId: number,
	player: Player,
	teleportData: { [string]: any }?
): (boolean, string?)
	assert(player, "No player")

	local ok, err = TeleportServiceUtils.promiseTeleport(placeId, player, { teleportData = teleportData }):Yield()
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
		TeleportServiceUtils._recordMockTeleport(player, placeId, {
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
	Mock-aware `TeleportService:TeleportAsync(placeId, players, teleportOptions)`, yielded out of
	[TeleportServiceUtils.promiseTeleport] -- so it retries like every other teleport now, and throws
	what the last attempt threw. Mock players in the batch are recorded (with the options' teleport
	data) and dropped from the engine call; a batch of only mocks skips the engine and returns nil.

	@server
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
	assert(type(players) == "table", "Bad players")

	local ok, result = TeleportServiceUtils.promiseTeleport(placeId, players, teleportOptions):Yield()
	if not ok then
		error(tostring(result), 2)
	end

	return result
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
	One server teleport request, and only ever one: a promise wrapper of `TeleportService:TeleportAsync`
	-- mock-aware too, recording mock players and resolving without an engine call when the batch is all
	mocks. Retrying is [TeleportServiceUtils.promiseTeleport]'s job.

	Unlike the client's request this one settles: TeleportAsync yields until the engine has accepted the
	teleport and throws when it has not, so the promise says which happened.

	@server
	@param placeId number
	@param players { Player }
	@param teleportOptions TeleportOptions?
	@return Promise<TeleportAsyncResult?>
]=]
function TeleportServiceUtils.promiseTeleportServerOnce(
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
			teleportAsyncResult = TeleportServiceUtils._executeTeleportServer(placeId, players, teleportOptions)
		end)
		if not ok then
			return reject(err)
		end

		return resolve(teleportAsyncResult)
	end)
end

--[=[
	One client teleport request, and only ever one. Issues a single `TeleportService:Teleport` and then
	reports what the engine says about it.

	Roblox cannot hold more than one outstanding request per player -- a second earns
	`Enum.TeleportResult.IsTeleporting`, and there is no API to cancel the first -- so this never asks
	twice. Retrying is [TeleportServiceUtils.promiseTeleportClient]'s job, and it may only ask again
	once this has rejected, which is the only evidence the request is gone.

	The promise reports failure alone: a teleport that works ends with the player leaving, so success
	stays pending until the client is gone. It rejects with the whole [TeleportFailedReportUtils.TeleportReport] rather than a
	message, so a caller can decide on `result`. Destroying it stops listening and rejects with
	nothing, letting a caller tell its own teardown from a refusal.

	```lua
	maid._teleport = TeleportServiceUtils.promiseTeleportClientOnce(placeId, Players.LocalPlayer, data)
		:Catch(function(report)
			if report then
				print(report.result, report.message)
			end
		end)
	```

	@client
	@param placeId number
	@param player Player -- the local player, or a PlayerMock standing in for one
	@param teleportData { [string]: any }?
	@return Promise<()> -- Pending while in flight; rejects with a TeleportFailedReportUtils.TeleportReport when refused.
]=]
function TeleportServiceUtils.promiseTeleportClientOnce(
	placeId: number,
	player: Player,
	teleportData: { [string]: any }?
): Promise.Promise<()>
	assert(type(placeId) == "number", "Bad placeId")
	assert(player, "No player")
	assert(teleportData == nil or type(teleportData) == "table", "Bad teleportData")
	TeleportServiceUtils._assertIsLocalPlayer(player)

	local promise = Promise.new()

	PromiseMaidUtils.whilePromise(promise, function(maid)
		-- Listening before asking, so a refusal the engine makes immediately still lands.
		TeleportServiceUtils._connectTeleportReported(maid, placeId, player, function(report)
			if not promise:IsPending() then
				return
			end

			if TeleportFailedReportUtils.isInFlight(report) then
				return
			end

			promise:Reject(report)
		end)

		-- The raw request, not the public teleport(): that one comes back through promiseTeleport, and
		-- promiseTeleport is what reaches this.
		local ok, err = TeleportServiceUtils._executeTeleportClient(placeId, player, teleportData)
		if not ok then
			-- The call raised, so no request was made and no report is coming. Said in the same shape a
			-- refusal arrives in, so every rejection this makes is a TeleportReport.
			promise:Reject(
				TeleportFailedReportUtils.new(placeId, Enum.TeleportResult.Failure, err or "Teleport failed")
			)
		end
	end)

	return promise
end

--[=[
	A teleport, whichever realm asks for it, retried while a refusal is worth asking about. The realm
	picks the request: a server batches through [TeleportServiceUtils.promiseTeleportServerOnce], a
	client sends itself through [TeleportServiceUtils.promiseTeleportClientOnce].

	One request is outstanding at a time: the next only goes out after the last has settled, which on
	the client is the only evidence Roblox gives that a request is gone. So a refusal the engine will
	only repeat ([TeleportFailedReportUtils.shouldRetry]) rejects at once rather than spending the
	budget, and a report that means the hop is still running never starts a second one.

	Where it settles differs because the realms differ, not because the shape does. A server teleport
	resolves with its `TeleportAsyncResult` -- the server is still here afterwards. A client teleporting
	itself reports only failure: a teleport that works ends with the player gone, so it stays pending
	until they are. Destroying it stops the retries and rejects with nothing either way, so a caller can
	tell its own teardown from a hop that genuinely failed.

	A server teleport resolves as soon as the engine accepts the request, which is not the same as the
	player going anywhere: a refusal raised afterwards (`Unauthorized`, most of all) would otherwise
	never reach the caller at all. `config.initFailedGraceSeconds` holds each attempt open that long to
	catch one -- see [TeleportServiceUtils._promiseTeleportServerAttempt]. Worth setting wherever
	something is waiting on the hop, because without it a refused teleport is indistinguishable from one
	still on its way.

	Rejects with the [TeleportFailedReportUtils.TeleportReport] itself when a refusal ends it, and with
	the retry wrapper's summary once the attempts are spent -- a report renders itself, so either reads
	as text.

	```lua
	-- Server: a batch, and the options every call passed before this was unified still work
	TeleportServiceUtils.promiseTeleport(placeId, { player }, teleportOptions)

	-- Client: itself
	maid._teleport = TeleportServiceUtils.promiseTeleport(placeId, Players.LocalPlayer, {
		teleportData = teleportData,
	})
	```

	@param placeId number
	@param players Player | { Player } -- one player or a batch; a client sends only itself
	@param configOrOptions TeleportConfig | TeleportOptions | nil -- a bare TeleportOptions reads as a config carrying it
	@return Promise<TeleportAsyncResult?> -- Resolves on a server; on a client, pending until the player is gone.
]=]
function TeleportServiceUtils.promiseTeleport(
	placeId: number,
	players: Player | { Player },
	configOrOptions: (TeleportConfig | TeleportOptions)?
): Promise.Promise<TeleportAsyncResult?>
	assert(type(placeId) == "number", "Bad placeId")
	assert(players, "No players")

	local config = TeleportServiceUtils._normalizeTeleportConfig(configOrOptions)
	local maxAttempts = config.maxAttempts or DEFAULT_MAX_ATTEMPTS
	local retryWait = config.retryWait or DEFAULT_RETRY_WAIT

	assert(config.teleportData == nil or type(config.teleportData) == "table", "Bad config.teleportData")
	assert(type(maxAttempts) == "number" and maxAttempts >= 1, "Bad config.maxAttempts")
	assert(type(retryWait) == "number" and retryWait >= 0, "Bad config.retryWait")

	local maid = Maid.new()

	local promise = PromiseRetryUtils.retry(function()
		local attempt = TeleportServiceUtils._promiseTeleportOnce(placeId, players, config)

		-- Held so cancelling the retry takes the outstanding request down with it: PromiseRetryUtils
		-- cancels its own loop, but never touches the promise a callback handed it.
		maid._attempt = attempt

		return attempt
	end, {
		initialWaitTime = retryWait,
		maxAttempts = maxAttempts,
		exponential = config.exponential or DEFAULT_EXPONENTIAL,
		printWarning = if config.printWarning ~= nil then config.printWarning else true,
		shouldRetry = function(rejection: any): boolean
			-- A cancelled attempt rejects with nothing -- the empty rejection consumers read as
			-- teardown -- and there is no refusal there to answer.
			if rejection == nil then
				return false
			end

			if TeleportFailedReportUtils.isReport(rejection) then
				return TeleportFailedReportUtils.shouldRetry(rejection)
			end

			-- A server refusal is whatever TeleportAsync threw, with no result to classify by. Nothing
			-- is outstanding once it has thrown, so asking again is at least safe.
			return true
		end,
	})

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

--[=[
	[TeleportServiceUtils.promiseTeleport] under the name a client used before either realm shared it.

	@client
	@deprecated 10.3.0 -- Use [TeleportServiceUtils.promiseTeleport], which does this in either realm.
	@param placeId number
	@param player Player -- the local player, or a PlayerMock standing in for one
	@param config TeleportClientConfig?
	@return Promise<()> -- Pending while in flight; rejects once the player is going nowhere.
]=]
function TeleportServiceUtils.promiseTeleportClient(
	placeId: number,
	player: Player,
	config: TeleportClientConfig?
): Promise.Promise<()>
	return TeleportServiceUtils.promiseTeleport(placeId, player, config) :: any
end

--[[
	Which realm this is running in, behind a seam because a test needs to drive both: --cloud runs
	server-side, where the client path would otherwise be unreachable.
]]
function TeleportServiceUtils._isServer(): boolean
	return RunService:IsServer()
end

--[[
	A client can only send itself. TeleportService:Teleport takes the local player and quietly does
	nothing useful with anyone else, so refuse it here where the caller can still see why.

	Measured against a designated mock as readily as the real thing, so a simulated client is held to
	the same rule. Where neither exists there is no local player to be, which is not a client at all --
	a bare unit test -- and nothing to check.
]]
function TeleportServiceUtils._assertIsLocalPlayer(player: Player): ()
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()

	assert(
		localPlayer == nil or player == localPlayer,
		"Cannot teleport a player other than the local player from a client"
	)
end

--[[
	The raw client request. Mock-aware, and the only place TeleportService:Teleport is reached.
]]
function TeleportServiceUtils._executeTeleportClient(
	placeId: number,
	player: Player,
	teleportData: { [string]: any }?
): (boolean, string?)
	assert(type(placeId) == "number", "Bad placeId")
	assert(player, "No player")

	if PlayerMock.isMock(player) then
		TeleportServiceUtils._recordMockTeleport(
			player,
			placeId,
			{ via = "Teleport", teleportData = teleportData or {} }
		)
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

--[[
	The raw server request. Mock-aware, and the only place TeleportService:TeleportAsync is reached.
]]
function TeleportServiceUtils._executeTeleportServer(
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
			TeleportServiceUtils._recordMockTeleport(
				player,
				placeId,
				{ via = "TeleportAsync", teleportData = teleportData }
			)
		else
			table.insert(realPlayers, player)
		end
	end

	if #realPlayers == 0 then
		return nil
	end

	return TeleportService:TeleportAsync(placeId, realPlayers, teleportOptions)
end

--[[
	One shape out of the two callers pass: a bare TeleportOptions -- what every server call passed
	before the realms shared this -- reads as a config carrying it, with its teleport data lifted out
	for a client that has no use for the options themselves.
]]
function TeleportServiceUtils._normalizeTeleportConfig(
	configOrOptions: (TeleportConfig | TeleportOptions)?
): TeleportConfig
	if configOrOptions == nil then
		return {}
	end

	if typeof(configOrOptions) == "Instance" then
		assert(configOrOptions:IsA("TeleportOptions"), "Bad teleportOptions")

		return {
			teleportOptions = configOrOptions,
			teleportData = configOrOptions:GetTeleportData() :: any,
		}
	end

	assert(type(configOrOptions) == "table", "Bad config")

	return configOrOptions
end

--[[
	The realm's own single request. A server takes the batch as given; a client can only send itself,
	so a batch means the one player it holds.
]]
function TeleportServiceUtils._promiseTeleportOnce(
	placeId: number,
	players: Player | { Player },
	config: TeleportConfig
): Promise.Promise<TeleportAsyncResult?>
	if TeleportServiceUtils._isServer() then
		local batch: { Player } = if type(players) == "table" then players else { players :: Player }
		local teleportOptions = config.teleportOptions

		if not teleportOptions and config.teleportData then
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData(config.teleportData)
			teleportOptions = options
		end

		return TeleportServiceUtils._promiseTeleportServerAttempt(
			placeId,
			batch,
			teleportOptions,
			config.initFailedGraceSeconds
		)
	end

	local player: Player = if type(players) == "table" then players[1] else players :: Player
	assert(player, "No player to teleport")

	return TeleportServiceUtils.promiseTeleportClientOnce(placeId, player, config.teleportData) :: any
end

--[[
	The server's own request, plus the grace window a config asked for.

	`TeleportAsync` comes back as soon as the engine has ACCEPTED the request. A refusal it makes after
	that -- a paid-access `Unauthorized` above all, which is raised rather than thrown -- arrives later
	through `TeleportInitFailed`, by which time a promise that resolved on acceptance has already called
	the hop underway and has nothing left to reject with. That is how a caller ends up waiting forever on
	a teleport that is never coming: the request was accepted, so nothing ever failed, so nothing ever
	settled.

	A config that asks for a window holds the attempt open that long after acceptance and rejects with
	the report if a refusal lands inside it -- handing the retry wrapper the same
	[TeleportFailedReportUtils.TeleportReport] a client attempt would, so `Unauthorized` ends the hop at
	once and `GameFull` spends an attempt like any other.

	Opt-in, because resolving late changes when an existing server caller hears back. What a resolution
	*means* is unchanged either way: the engine accepted the request.
]]
function TeleportServiceUtils._promiseTeleportServerAttempt(
	placeId: number,
	batch: { Player },
	teleportOptions: TeleportOptions?,
	graceSeconds: number?
): Promise.Promise<TeleportAsyncResult?>
	local accepted = TeleportServiceUtils.promiseTeleportServerOnce(placeId, batch, teleportOptions)
	if graceSeconds == nil or graceSeconds <= 0 then
		return accepted
	end

	local promise = Promise.new()

	PromiseMaidUtils.whilePromise(promise, function(maid)
		-- Listening starts before the request settles: the engine can refuse one player of a batch while
		-- TeleportAsync is still yielding over the rest.
		for _, player in batch do
			TeleportServiceUtils._connectTeleportReported(maid, placeId, player, function(report)
				if TeleportFailedReportUtils.isInFlight(report) then
					return
				end

				promise:Reject(report)
			end)
		end

		-- Not held by the maid: an engine request in flight cannot be cancelled, so there is nothing for
		-- a teardown to take back. Its rejection is consumed here either way.
		accepted:Then(function(result)
			maid:GiveTask(task.delay(graceSeconds, function()
				promise:Resolve(result)
			end))
		end, function(err)
			promise:Reject(err)
		end)
	end)

	return promise
end

--[[
	A teleport the engine never saw, written where a test reads it back.
]]
function TeleportServiceUtils._recordMockTeleport(player: Player, placeId: number, record: MockTeleport): ()
	PlayerMock.writeLookup(player, "TeleportService.Teleport", placeId, record)
end

--[[
	Hands the maid every report the engine makes about THIS player's hop to THIS place, mock and engine
	alike, in one shape. TeleportInitFailed reports outcomes rather than only failures -- Success and
	IsTeleporting both arrive through it -- so this only delivers, and the caller classifies.
]]
function TeleportServiceUtils._connectTeleportReported(
	maid: Maid.Maid,
	placeId: number,
	player: Player,
	onReport: (report: TeleportFailedReportUtils.TeleportReport) -> ()
): ()
	if PlayerMock.isMock(player) then
		maid:GiveTask(
			PlayerMock.getLookupChangedSignal(player, "TeleportService.TeleportInitFailed", placeId):Connect(function()
				local injected = PlayerMock.readLookup(player, "TeleportService.TeleportInitFailed", placeId)
				if injected == nil then
					return
				end

				onReport(TeleportFailedReportUtils.new(placeId, injected.result, injected.message))
			end)
		)
		return
	end

	maid:GiveTask(
		TeleportService.TeleportInitFailed:Connect(
			function(failedPlayer: Player, result: Enum.TeleportResult, message: string, reportedPlaceId: number?)
				if failedPlayer ~= player then
					return
				end

				-- Keyed by destination like the mock is, so a hop to somewhere else failing never speaks for
				-- this one. Tolerates the engine omitting the place rather than dropping every report.
				if reportedPlaceId ~= nil and reportedPlaceId ~= placeId then
					return
				end

				onReport(TeleportFailedReportUtils.new(placeId, result, message))
			end
		)
	)
end

return TeleportServiceUtils
