--!strict
--[=[
	Cmdr commands for inspecting and stress-testing player datastores, for customer service and
	debugging.

	Targets come in as `playerIds`, so the same command reaches a player in this server (`.`, `*`, a
	name) and one who is not (a name Cmdr resolves through `GetUserIdFromNameAsync`, or `#userId` for
	an account whose name is unknown or since changed).

	There are two families here, and they reach the key differently.

	The lock commands (`datastore-lock-info`, `datastore-lock`, `datastore-unlock`) write the key
	directly without opening a session, so they act on a lock left behind by a server that died --
	the usual reason to reach for them.

	The data commands (`datastore-read-json`, `datastore-write-json`, `datastore-delete`,
	`datastore-copy`) go through a real [DataStore], which means they **steal the session** from
	whichever server holds it, including this one. That is deliberate: these exist to stress-test the
	session-locking system, and a read that cannot be starved of a current write is exactly what is
	being tested. A player whose session is stolen mid-play is disrupted -- they are kicked when their
	server notices -- so treat these as debug tooling rather than customer-service tooling.

	:::warning
	The session lock is soft. A loading session steals it once its retry ladder is exhausted, so
	`datastore-lock` parks a key for that long and no longer. Unlocking is the durable half.
	:::

	:::info
	TODO: give the read paths a read-only [DataStore] so they stop stealing. The load path already
	uses a plain `GetAsync` and takes no lock, so the store itself is a thin flag -- but a read that
	is guaranteed to see the *current* write needs MessagingService to ask the holding session to
	flush first, plus the edge cases around a session that never answers. Deferred rather than
	half-built.
	:::

	@server
	@class DataStoreCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local CmdrReplyUtils = require("CmdrReplyUtils")
local CmdrService = require("CmdrService")
local CmdrTypes = require("CmdrTypes")
local DataStoreCmdrUtils = require("DataStoreCmdrUtils")
local DataStoreLockUtils = require("DataStoreLockUtils")
local DataStoreStage = require("DataStoreStage")
local Maid = require("Maid")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local DataStoreCmdrService = {}
DataStoreCmdrService.ServiceName = "DataStoreCmdrService"

export type DataStoreCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_playerDataStoreService: any,
		_replyConfig: CmdrReplyUtils.CmdrReplyConfig,
	},
	{} :: typeof({ __index = DataStoreCmdrService })
))

type Manager = PlayerDataStoreManager.PlayerDataStoreManager
type UserIdHandler = (Manager, number) -> Promise.Promise<string>
type CommandContext = CmdrTypes.CommandContext

--[[
	Walks a sub-store path from a store, returning the store itself for an empty path.
]]
local function resolveSubStore(
	dataStoreStage: DataStoreStage.DataStoreStage,
	path: { string }
): DataStoreStage.DataStoreStage
	local current = dataStoreStage
	for _, segment in path do
		current = current:GetSubStore(segment)
	end

	return current
end

--[=[
	Initializes the service. Should be done via [ServiceBag.Init].
	@param serviceBag ServiceBag
]=]
function DataStoreCmdrService.Init(self: DataStoreCmdrService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._replyConfig = CmdrReplyUtils.createConfig()

	-- External
	self._cmdrService = self._serviceBag:GetService(CmdrService)

	-- Reached through the module instance rather than by name, because
	-- `require("PlayerDataStoreService")` from here is a cyclic module dependency:
	-- PlayerDataStoreService registers this service. Mirrors SaveSlotCmdrService._getSaveSlotService.
	local serviceModule =
		assert(script.Parent.Parent:FindFirstChild("PlayerDataStoreService"), "No PlayerDataStoreService")
	self._playerDataStoreService = self._serviceBag:GetService(serviceModule)
end

--[=[
	Sets how long a command may run before it tells the executor it is still working, and how that
	line is colored.

	@param replyConfig CmdrReplyConfig -- see [CmdrReplyUtils.createConfig]
]=]
function DataStoreCmdrService.SetReplyConfig(
	self: DataStoreCmdrService,
	replyConfig: CmdrReplyUtils.CmdrReplyConfig
): ()
	assert(CmdrReplyUtils.isCmdrReplyConfig(replyConfig), "Bad replyConfig")

	self._replyConfig = replyConfig
end

--[=[
	Registers the commands. Should be done via [ServiceBag.Start].
]=]
function DataStoreCmdrService.Start(self: DataStoreCmdrService): ()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		DataStoreCmdrUtils.registerSubStoreType(cmdr)

		self:_registerCommands()
	end)
end

function DataStoreCmdrService._registerCommands(self: DataStoreCmdrService): ()
	local playersArg = {
		Name = "Players",
		Type = "playerIds",
		Description = "Players to act on (e.g. . for yourself, * for everyone here, a username, or #userId).",
	}

	local subStoreArg = {
		Name = "SubStore",
		Type = "dataStoreSubStore",
		Description = "Sub-store path to scope to, slash-delimited (e.g. SaveSlotSystem/Metadata). Omit for the whole key.",
		Optional = true,
	}

	self._cmdrService:RegisterCommand({
		Name = "datastore-lock-info",
		Description = "Reads the session lock on each player's datastore key. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = { playersArg },
	}, function(context: CommandContext, userIds: { number })
		return self:_executeForUserIds(context, userIds, function(manager, userId)
			return manager:PromiseReadSessionLock(userId):Then(function(lockData)
				return `{userId}: {DataStoreLockUtils.toHumanReadable(lockData)}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "datastore-unlock",
		Description = "Clears the session lock on each player's datastore key, releasing a claim left behind by a dead server. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = { playersArg },
	}, function(context: CommandContext, userIds: { number })
		return self:_executeForUserIds(context, userIds, function(manager, userId)
			return manager:PromiseUnlockSession(userId):Then(function(previousLock)
				if previousLock == nil or previousLock.ActiveSession == nil then
					return `{userId} was already unlocked. Nothing to do.`
				end

				return `Unlocked {userId}. Cleared: {DataStoreLockUtils.toHumanReadable(previousLock)}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "datastore-lock",
		Description = "Claims each player's datastore key so an inspection is not racing a live server. Soft: a loading session steals it once its retry ladder runs out. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = { playersArg },
	}, function(context: CommandContext, userIds: { number })
		return self:_executeForUserIds(context, userIds, function(manager, userId)
			return manager:PromiseLockSession(userId):Then(function(previousLock)
				if previousLock == nil or previousLock.ActiveSession == nil then
					return `Locked {userId}.`
				end

				return `Locked {userId}, replacing: {DataStoreLockUtils.toHumanReadable(previousLock)}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "datastore-read-json",
		Description = "Reads each player's datastore as JSON. Steals the session. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = { playersArg, subStoreArg },
	}, function(context: CommandContext, userIds: { number }, path: { string }?)
		return self:_executeForUserIds(context, userIds, function(manager, userId)
			return self:_promiseWithDataStore(manager, userId, false, function(dataStore)
				return resolveSubStore(dataStore, path or {}):LoadAll({}):Then(function(data)
					return `-- {userId} {self:_describePath(path)}\n{HttpService:JSONEncode(data)}`
				end)
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "datastore-write-json",
		Description = "Overwrites each player's datastore with the given JSON. Steals the session. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = {
			playersArg,
			-- Ahead of the optional sub-store, since Cmdr can only leave trailing arguments off.
			{
				Name = "Json",
				Type = "string",
				Description = "JSON object to write.",
			},
			subStoreArg,
		},
	}, function(context: CommandContext, userIds: { number }, json: string, path: { string }?)
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
		if not ok then
			return `Failed: could not decode JSON: {tostring(decoded)}`
		end

		return self:_executeForUserIds(context, userIds, function(manager, userId)
			return self:_promiseWithDataStore(manager, userId, true, function(dataStore)
				resolveSubStore(dataStore, path or {}):Overwrite(decoded)
				return Promise.resolved(`Wrote {userId} {self:_describePath(path)}.`)
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "datastore-delete",
		Description = "Wipes each player's datastore, or one sub-store of it. Steals the session. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = { playersArg, subStoreArg },
	}, function(context: CommandContext, userIds: { number }, path: { string }?)
		return self:_executeForUserIds(context, userIds, function(manager, userId)
			return self:_promiseWithDataStore(manager, userId, true, function(dataStore)
				resolveSubStore(dataStore, path or {}):Wipe()
				return Promise.resolved(`Deleted {userId} {self:_describePath(path)}.`)
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "datastore-copy",
		Description = "Copies one player's datastore over others'. Steals the session from every player involved. Works remotely and on players in-game.",
		Group = "DataStore",
		Args = {
			{
				Name = "FromPlayer",
				Type = "playerId",
				Description = "Player to copy from (e.g. . for yourself, a username, or #userId).",
			},
			{
				Name = "ToPlayers",
				Type = "playerIds",
				Description = "Players to copy onto (e.g. . for yourself, a username, or #userId).",
			},
			subStoreArg,
		},
	}, function(context: CommandContext, fromUserId: number, toUserIds: { number }, path: { string }?)
		local readPromise = self._playerDataStoreService:PromiseManager():Then(function(manager)
			return self:_promiseWithDataStore(manager, fromUserId, false, function(dataStore)
				return resolveSubStore(dataStore, path or {}):LoadAll({})
			end)
		end)

		CmdrReplyUtils.replyWhenSlow(self._replyConfig, context, readPromise, `{fromUserId}: still reading...`)

		local ok, source = self._maid:GivePromise(readPromise):Yield()
		if not ok then
			return `Failed to read {fromUserId}: {tostring(source)}`
		end

		return self:_executeForUserIds(context, toUserIds, function(manager, userId)
			if userId == fromUserId then
				return Promise.resolved(`{userId} is the source. Skipped.`)
			end

			return self:_promiseWithDataStore(manager, userId, true, function(dataStore)
				resolveSubStore(dataStore, path or {}):Overwrite(source)
				return Promise.resolved(`Copied {fromUserId} {self:_describePath(path)} onto {userId}.`)
			end)
		end)
	end)
end

--[=[
	Opens the store for `userId`, runs `handler` against it, and puts it back.

	[PlayerDataStoreManager.PromiseDataStore] opens a real session, which takes the lock from whoever
	holds it -- kicking that player when their server notices the theft. Releasing what was taken is
	therefore the part that matters: an orphaned lock is exactly what `datastore-unlock` exists to
	clear, and until it is dropped the player cannot rejoin.

	So a store opened for an absent player is closed again, and the promise waits for that flush to
	land rather than reporting success while the lock is still held. A store belonging to a player in
	this server is left alone instead: no session was stolen, and removing it would strand a live one.

	@param manager PlayerDataStoreManager
	@param userId number
	@param doesWrite boolean -- whether to flush before handing a live store back
	@param handler (DataStore) -> Promise<T>
	@return Promise<T>
]=]
function DataStoreCmdrService._promiseWithDataStore(
	self: DataStoreCmdrService,
	manager: Manager,
	userId: number,
	doesWrite: boolean,
	handler: (any) -> Promise.Promise<any>
): Promise.Promise<any>
	local isInThisServer = Players:GetPlayerByUserId(userId) ~= nil

	-- Deliberately not `_maid:GivePromise`, which cancels nothing upstream: on teardown the handle
	-- still resolves, into a continuation the maid has already skipped, and the session it took stays
	-- locked for the rest of the server's life. The maid is probed for liveness instead, and then
	-- handed the handle itself.
	local probe = {}
	self._maid[probe] = probe

	return manager:PromiseDataStoreHandle(userId):Then(function(handle)
		local isAlive = self._maid[probe] == probe
		self._maid[probe] = nil

		if not isAlive then
			handle:Destroy()
			return Promise.rejected(`Destroyed while opening the datastore for {userId}`)
		end

		local handleId = self._maid:GiveTask(handle :: any)

		local function release(): Promise.Promise<()>
			-- A write only stages, so a command can reach here with the opening load still in flight.
			-- Releasing then destroys the store out from under it, and the UpdateAsync Roblox has
			-- already dispatched calls back into the wreckage. Let the load settle first. Resolves
			-- either way -- a load that failed is still a load that is no longer running.
			return handle:GetDataStore():PromiseLoadSuccessful():Then(function()
				-- Destroying the handle closes a borrowed session and flushes it. A live player's store
				-- is not the handle's to close, so that one is saved explicitly instead.
				local savePromise: Promise.Promise<()> = Promise.resolved()
				if isInThisServer and doesWrite then
					savePromise = handle:GetDataStore():Save()
				end

				return savePromise:Finally(function()
					self._maid[handleId] = nil

					-- Destroying the handle only *starts* the save-and-close, so wait for it here: the
					-- command reports success once the lock it took is gone, not while it is still held.
					return manager:PromiseSessionClosed(userId)
				end)
			end)
		end

		return handler(handle:GetDataStore()):Then(function(result)
			return release():Then(function()
				return result
			end)
		end, function(err)
			return release():Then(function()
				return Promise.rejected(err)
			end)
		end)
	end, function(err)
		-- The open failed, so there is no handle to hand to the maid. Take the probe back out.
		self._maid[probe] = nil
		return Promise.rejected(err)
	end)
end

--[=[
	Runs `handler` once per target userId and renders the results back into the console.

	Runs sequentially, to keep a batch from firing concurrent writes at the datastore. A target that
	fails reports on its own line rather than throwing into Cmdr or costing the rest of the batch its
	result.

	Nothing reaches the console until every target is done, and a single target can sit in a load
	retry ladder for a long time, so a target still going after the reply config's
	`slowReplySeconds` says so.

	@param context CommandContext
	@param userIds { number }
	@param handler (PlayerDataStoreManager, number) -> Promise<string>
	@return string
]=]
function DataStoreCmdrService._executeForUserIds(
	self: DataStoreCmdrService,
	context: CommandContext,
	userIds: { number },
	handler: UserIdHandler
): string
	if #userIds == 0 then
		return "No players to act on."
	end

	local promise = self._playerDataStoreService:PromiseManager():Then(function(manager)
		local chain = Promise.resolved()
		local lines: { string } = {}

		for _, userId in userIds do
			chain = chain:Then(function()
				return CmdrReplyUtils.replyWhenSlow(
					self._replyConfig,
					context,
					handler(manager, userId),
					`{userId}: still working...`
				)
					:Then(function(line)
						table.insert(lines, line)
					end)
					:Catch(function(err)
						table.insert(lines, `{userId}: Failed: {tostring(err)}`)
					end)
			end)
		end

		return chain:Then(function()
			return lines
		end)
	end)

	local ok, result = self._maid:GivePromise(promise):Yield()
	if not ok then
		return `Failed: {tostring(result)}`
	end

	return table.concat(result, "\n")
end

function DataStoreCmdrService._describePath(_self: DataStoreCmdrService, path: { string }?): string
	if path == nil or #path == 0 then
		return "(whole key)"
	end

	return table.concat(path, "/")
end

function DataStoreCmdrService.Destroy(self: DataStoreCmdrService): ()
	self._maid:DoCleaning()
end

return DataStoreCmdrService
