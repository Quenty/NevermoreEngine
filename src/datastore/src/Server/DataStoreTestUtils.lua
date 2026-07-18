--!nonstrict
--[=[
	Shared setup helpers for the DataStore server specs. The two controller builders --
	[DataStoreTestUtils.setup] (raw DataStores) and [DataStoreTestUtils.setupDataStoreManager]
	(a [PlayerDataStoreManager]) -- each own a [Maid] and register everything they create on it, so a
	single `controller:destroy()` tears it all down: the stores, the auto-save loop each starts once
	loaded, the helpers, the manager, and the service bag.

	@class DataStoreTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreLockHelper = require("DataStoreLockHelper")
local DataStoreMessageHelper = require("DataStoreMessageHelper")
local DataStoreMock = require("DataStoreMock")
local Maid = require("Maid")
local MessagingServiceMock = require("MessagingServiceMock")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local DataStoreTestUtils = {}

--[=[
	Builds the controller the DataStore specs share: a fresh [DataStoreMock], a [ServiceBag] with an
	in-process [MessagingServiceMock] injected (so messaging-enabled stores never touch the real
	MessagingService), and builder methods that own everything they create on one Maid. `destroy()`
	tears it all down. Every builder defaults its key to `"player_1"`; pass a key to override.

	Fields: `mock`, `serviceBag`.
	Builders: `newDataStore(key?)`, `newSessionLockedStore(key?, userIdList?)`, `newLockHelper(key?)`
	(returns `helper, dataStore`), `newMessageHelper(dataStore?)` (returns `helper, dataStore`),
	`newServer(opts?)` (returns `dataStore, helper?`; `opts` = `{ key?, messaging?, autoCloseOnRequest? }`).
	Helpers: `awaitOwn(dataStore)` -> boolean (loads and reports whether we own the session).

	@return { ... }
]=]
function DataStoreTestUtils.setup()
	local maid = Maid.new()

	local mock = DataStoreMock.new()
	local serviceBag = DataStoreTestUtils.newServiceBag(maid, MessagingServiceMock.new())

	local function newDataStore(key)
		return DataStoreTestUtils.newDataStore(maid, mock, key or "player_1")
	end

	local function newSessionLockedStore(key, userIdList)
		return DataStoreTestUtils.newSessionLockedStore(maid, mock, key or "player_1", userIdList)
	end

	local function newLockHelper(key)
		local dataStore = newDataStore(key)
		local helper = maid:Add(DataStoreLockHelper.new(dataStore))
		return helper, dataStore
	end

	local function newMessageHelper(dataStore)
		dataStore = dataStore or newDataStore()
		return DataStoreTestUtils.newMessageHelper(maid, serviceBag, dataStore), dataStore
	end

	local function newServer(opts)
		opts = opts or {}
		local dataStore = newSessionLockedStore(opts.key)
		local helper
		if opts.messaging then
			dataStore:SetSessionMessagingEnabled(true, serviceBag)
			helper = newMessageHelper(dataStore)
		end
		if opts.autoCloseOnRequest then
			dataStore.SessionCloseRequested:Connect(function()
				dataStore:SaveAndCloseSession()
			end)
		end
		return dataStore, helper
	end

	local function awaitOwn(dataStore)
		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			return false
		end
		local ok, loadedOk = promise:Yield()
		return ok and loadedOk
	end

	return {
		mock = mock,
		serviceBag = serviceBag,
		newDataStore = newDataStore,
		newSessionLockedStore = newSessionLockedStore,
		newLockHelper = newLockHelper,
		newMessageHelper = newMessageHelper,
		newServer = newServer,
		awaitOwn = awaitOwn,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

--[=[
	Builds the controller the [PlayerDataStoreManager] specs share: a session-locked manager wired to
	a fresh [DataStoreMock] (keyed `user_<userId>`), all owned by a Maid. `destroy()` tears down the
	manager (and the loaded stores whose auto-save loops it owns) and the service bag.

	Fields: `manager`, `mock`, `serviceBag`.
	Helpers: `storeAndAwaitLock()` -> boolean -- stores a value on user 1's store and waits for the
	session-locked load to write the lock envelope.

	@return { manager: PlayerDataStoreManager, mock: DataStoreMock, ... }
]=]
function DataStoreTestUtils.setupDataStoreManager()
	local maid = Maid.new()

	local mock = DataStoreMock.new()
	local serviceBag = DataStoreTestUtils.newServiceBag(maid)

	local manager = maid:Add(PlayerDataStoreManager.new(serviceBag, mock, function(userId)
		return "user_" .. tostring(userId)
	end, true))

	local function storeAndAwaitLock()
		local dataStore = manager:GetDataStore(1)
		dataStore:Store("coins", 5)
		-- The session-locked load acquires the lock (writes the envelope) before we remove.
		return PromiseTestUtils.awaitValue(function()
			local raw = mock:GetRaw("user_1")
			return raw ~= nil and raw.lock ~= nil
		end, 10)
	end

	return {
		manager = manager,
		mock = mock,
		serviceBag = serviceBag,
		storeAndAwaitLock = storeAndAwaitLock,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

--[=[
	Builds a [ServiceBag] with PlaceMessagingService registered and Init/Start'd, owned by the maid.
	Pass a Roblox MessagingService mock to inject it into PlaceMessagingService between Init and Start.

	@param maid Maid
	@param robloxMessagingService MessagingServiceMock? -- injected when provided
	@return ServiceBag
]=]
function DataStoreTestUtils.newServiceBag(maid, robloxMessagingService)
	local serviceBag = maid:Add(ServiceBag.new())
	local placeMessagingService = serviceBag:GetService(require("PlaceMessagingService"))
	serviceBag:Init()
	if robloxMessagingService then
		placeMessagingService:SetRobloxMessagingService(robloxMessagingService)
	end
	serviceBag:Start()
	return serviceBag
end

--[=[
	Builds a [DataStore] over `mock` and owns it with the maid.

	@param maid Maid
	@param mock DataStoreMock
	@param key string
	@return DataStore
]=]
function DataStoreTestUtils.newDataStore(maid, mock, key)
	return maid:Add(DataStore.new(mock, key))
end

--[=[
	Builds a session-locked [DataStore] over `mock` and owns it with the maid.

	@param maid Maid
	@param mock DataStoreMock
	@param key string
	@param userIdList { number }? -- defaults to { 1 }
	@return DataStore
]=]
function DataStoreTestUtils.newSessionLockedStore(maid, mock, key, userIdList)
	local dataStore = maid:Add(DataStore.new(mock, key))
	dataStore:SetSessionLockingEnabled(true)
	dataStore:SetUserIdList(userIdList or { 1 })
	return dataStore
end

--[=[
	Builds a [DataStoreMessageHelper] over `dataStore` and owns it with the maid.

	@param maid Maid
	@param serviceBag ServiceBag
	@param dataStore DataStore
	@return DataStoreMessageHelper
]=]
function DataStoreTestUtils.newMessageHelper(maid, serviceBag, dataStore)
	return maid:Add(DataStoreMessageHelper.new(serviceBag, dataStore))
end

return DataStoreTestUtils
