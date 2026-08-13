--!strict
--[=[
	Centralized service using serviceBag. This will let other packages work with a single player datastore service.

	@server
	@class PlayerDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local PlayerDataStoreHandle = require("PlayerDataStoreHandle")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local Promise = require("Promise")
local PromiseRetryUtils = require("PromiseRetryUtils")
local ServiceBag = require("ServiceBag")

local PlayerDataStoreService = {}
PlayerDataStoreService.ServiceName = "PlayerDataStoreService"

export type PlayerDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_dataStoreName: string,
		_dataStoreScope: string,
		_dataStoreManagerPromise: Promise.Promise<PlayerDataStoreManager.PlayerDataStoreManager>,
		_bindToCloseService: any,
		_promiseStarted: Promise.Promise<()>,
		_robloxDataStoreOverride: any?,
		_loadRetryOptions: PromiseRetryUtils.RetryOptions?,
		_autoSaveTimeSeconds: number?,
		_autoSaveTimeSecondsSet: boolean,
		_sessionMessagingCloseDelaySeconds: number?,
	},
	{} :: typeof({ __index = PlayerDataStoreService })
))

--[=[
	Initializes the PlayerDataStoreService. Should be done via [ServiceBag.Init].
	@param serviceBag ServiceBag
]=]
function PlayerDataStoreService.Init(self: PlayerDataStoreService, serviceBag: ServiceBag.ServiceBag): ()
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))
	self._serviceBag:GetService(require("PlaceMessagingService"))

	-- State
	self._promiseStarted = self._maid:Add(Promise.new())
	self._dataStoreName = "PlayerData"
	self._dataStoreScope = "SaveData"
	self._autoSaveTimeSecondsSet = false
end

--[=[
	Initializes the datastore service for players. Should be done via [ServiceBag.Start].
]=]
function PlayerDataStoreService.Start(self: PlayerDataStoreService): ()
	-- Give time for configuration
	self._promiseStarted:Resolve()
end

--[=[
	Sets the name for the datastore to retrieve.

	:::info
	Must be done before start and after init.
	:::

	@param dataStoreName string
]=]
function PlayerDataStoreService.SetDataStoreName(self: PlayerDataStoreService, dataStoreName: string): ()
	assert(type(dataStoreName) == "string", "Bad dataStoreName")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._dataStoreName = dataStoreName
end

--[=[
	Sets the scope for the datastore to retrieve.

	:::info
	Must be done before start and after init.
	:::

	@param dataStoreScope string
]=]
function PlayerDataStoreService.SetDataStoreScope(self: PlayerDataStoreService, dataStoreScope: string): ()
	assert(type(dataStoreScope) == "string", "Bad dataStoreScope")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._dataStoreScope = dataStoreScope
end

--[=[
	Overrides the load retry backoff on every player datastore. See
	[PlayerDataStoreManager.SetLoadRetryOptions] -- this is what decides how long a player waits on a
	lock held by a dead server before it is stolen.

	:::info
	Must be done before start and after init.
	:::

	@param options RetryOptions
]=]
function PlayerDataStoreService.SetLoadRetryOptions(
	self: PlayerDataStoreService,
	options: PromiseRetryUtils.RetryOptions
): ()
	assert(type(options) == "table", "Bad options")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._loadRetryOptions = options
end

--[=[
	Sets the autosave interval on every player datastore. See
	[PlayerDataStoreManager.SetAutoSaveTimeSeconds].

	:::info
	Must be done before start and after init.
	:::

	@param autoSaveTimeSeconds number?
]=]
function PlayerDataStoreService.SetAutoSaveTimeSeconds(self: PlayerDataStoreService, autoSaveTimeSeconds: number?): ()
	assert(type(autoSaveTimeSeconds) == "number" or autoSaveTimeSeconds == nil, "Bad autoSaveTimeSeconds")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._autoSaveTimeSeconds = autoSaveTimeSeconds
	self._autoSaveTimeSecondsSet = true
end

--[=[
	Sets the post-graceful-close replication delay on every player datastore. See
	[PlayerDataStoreManager.SetSessionMessagingCloseDelaySeconds].

	:::info
	Must be done before start and after init.
	:::

	@param seconds number
]=]
function PlayerDataStoreService.SetSessionMessagingCloseDelaySeconds(self: PlayerDataStoreService, seconds: number): ()
	assert(type(seconds) == "number" and seconds >= 0, "Bad seconds")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._sessionMessagingCloseDelaySeconds = seconds
end

--[=[
	Injects the underlying datastore the manager wraps, instead of resolving a real one. Accepts
	a real datastore or a [DataStoreMock]. Intended for testing; must be called before the manager
	is first built.

	@param robloxDataStore DataStore | DataStoreMock
]=]
function PlayerDataStoreService.SetRobloxDataStore(self: PlayerDataStoreService, robloxDataStore: any): ()
	assert(DataStorePromises.isDataStore(robloxDataStore), "Bad robloxDataStore")
	assert(not self._dataStoreManagerPromise, "Already built manager, cannot override")

	self._robloxDataStoreOverride = robloxDataStore
end

--[=[
	Gets the datastore for the player.

	:::tip
	If you get the datastore by UserId, be sure to call datastore:PromiseCloseSession()
	when done to avoid session leaks.
	:::

	@param player Player | number
	@return Promise<DataStore>
]=]
function PlayerDataStoreService.PromiseDataStore(
	self: PlayerDataStoreService,
	player: Player | number
): Promise.Promise<DataStore.DataStore>
	return self:PromiseManager():Then(function(manager)
		return manager:PromiseDataStore(player)
	end)
end

--[=[
	Borrows the player's [DataStore] as a [PlayerDataStoreHandle], which releases the session when
	destroyed. Prefer this over [PlayerDataStoreService.PromiseDataStore] when acting on a player by
	userId, since it is what makes the release hard to forget -- see [PlayerDataStoreHandle].

	@param playerOrUserId Player | number
	@return Promise<PlayerDataStoreHandle>
]=]
function PlayerDataStoreService.PromiseDataStoreHandle(
	self: PlayerDataStoreService,
	playerOrUserId: Player | number
): Promise.Promise<PlayerDataStoreHandle.PlayerDataStoreHandle>
	return self:PromiseManager():Then(function(manager)
		return manager:PromiseDataStoreHandle(playerOrUserId)
	end)
end

--[=[
	Resolves once any removal in flight for this player has saved and closed their session -- see
	[PlayerDataStoreManager.PromiseSessionClosed].

	@param playerOrUserId Player | number
	@return Promise<()>
]=]
function PlayerDataStoreService.PromiseSessionClosed(
	self: PlayerDataStoreService,
	playerOrUserId: Player | number
): Promise.Promise<()>
	return self:PromiseManager():Then(function(manager)
		return manager:PromiseSessionClosed(playerOrUserId)
	end)
end

--[=[
	Adds a removing callback to the manager.
	@param callback function -- May return a promise
	@return Promise
]=]
function PlayerDataStoreService.PromiseAddRemovingCallback(
	self: PlayerDataStoreService,
	callback: () -> Promise.Promise<any>?
): Promise.Promise<()>
	return self:PromiseManager():Then(function(manager)
		manager:AddRemovingCallback(callback)
	end)
end

--[=[
	Retrieves the manager
	@return Promise<PlayerDataStoreManager>
]=]
function PlayerDataStoreService.PromiseManager(
	self: PlayerDataStoreService
): Promise.Promise<PlayerDataStoreManager.PlayerDataStoreManager>
	if self._dataStoreManagerPromise then
		return self._dataStoreManagerPromise
	end

	self._dataStoreManagerPromise = self._promiseStarted
		:Then(function()
			if self._robloxDataStoreOverride then
				return self._robloxDataStoreOverride
			end
			return DataStorePromises.promiseDataStore(self._dataStoreName, self._dataStoreScope)
		end)
		:Then(function(dataStore)
			local manager = self._maid:Add(PlayerDataStoreManager.new(self._serviceBag, dataStore, function(player)
				if type(player) == "number" then
					return tostring(player)
				else
					return tostring(player.UserId)
				end
			end, true))

			if self._loadRetryOptions then
				manager:SetLoadRetryOptions(self._loadRetryOptions)
			end
			if self._autoSaveTimeSecondsSet then
				manager:SetAutoSaveTimeSeconds(self._autoSaveTimeSeconds)
			end
			if self._sessionMessagingCloseDelaySeconds then
				manager:SetSessionMessagingCloseDelaySeconds(self._sessionMessagingCloseDelaySeconds)
			end

			-- A lot safer if we're hot reloading or need to monitor bind to close calls
			self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
				return manager:PromiseAllSaves()
			end))

			return manager
		end)
	assert(self._dataStoreManagerPromise, "Typechecking assertion")

	return self._dataStoreManagerPromise
end

function PlayerDataStoreService.Destroy(self: PlayerDataStoreService): ()
	self._maid:DoCleaning()
end

return PlayerDataStoreService
