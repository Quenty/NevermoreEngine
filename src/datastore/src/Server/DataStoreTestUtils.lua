--!strict
--[=[
	Shared setup helpers for the DataStore server specs.

	@class DataStoreTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local BindToCloseService = require("BindToCloseService")
local DataStore = require("DataStore")
local DataStoreLockHelper = require("DataStoreLockHelper")
local DataStoreMessageHelper = require("DataStoreMessageHelper")
local DataStoreMock = require("DataStoreMock")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local MessagingServiceMock = require("MessagingServiceMock")
local PlaceMessagingService = require("PlaceMessagingService")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local DataStoreTestUtils = {}

export type ServerOptions = {
	key: string?,
	messaging: boolean?,
	autoCloseOnRequest: boolean?,
}

export type DataStoreTestController = {
	maid: Maid.Maid,
	mock: DataStoreMock.DataStoreMock,
	serviceBag: ServiceBag.ServiceBag,
	newDataStore: (key: string?) -> DataStore.DataStore,
	newSessionLockedStore: (key: string?, userIdList: { number }?) -> DataStore.DataStore,
	newLockHelper: (key: string?) -> (DataStoreLockHelper.DataStoreLockHelper, DataStore.DataStore),
	newMessageHelper: (
		dataStore: DataStore.DataStore?
	) -> (DataStoreMessageHelper.DataStoreMessageHelper, DataStore.DataStore),
	newServer: (opts: ServerOptions?) -> (DataStore.DataStore, DataStoreMessageHelper.DataStoreMessageHelper?),
	awaitOwn: (dataStore: DataStore.DataStore) -> boolean,
	Destroy: (self: DataStoreTestController) -> (),
}

export type DataStoreManagerTestController = {
	manager: PlayerDataStoreManager.PlayerDataStoreManager,
	mock: DataStoreMock.DataStoreMock,
	serviceBag: ServiceBag.ServiceBag,
	bindToCloseService: BindToCloseService.BindToCloseService,
	storeAndAwaitLock: () -> boolean,
	Destroy: (self: DataStoreManagerTestController) -> (),
}

--[=[
	Builds a controller over a fresh [DataStoreMock] and a [ServiceBag] with a [MessagingServiceMock]
	injected. Everything it builds is cleaned up on `Destroy`.

	@return DataStoreTestController
]=]
function DataStoreTestUtils.setup(): DataStoreTestController
	local maid = Maid.new()

	local mock = DataStoreMock.new()
	local serviceBag = DataStoreTestUtils.newServiceBag(maid, MessagingServiceMock.new())

	local function newDataStore(key: string?): DataStore.DataStore
		return DataStoreTestUtils.newDataStore(maid, mock, key or "player_1")
	end

	local function newSessionLockedStore(key: string?, userIdList: { number }?): DataStore.DataStore
		return DataStoreTestUtils.newSessionLockedStore(maid, mock, key or "player_1", userIdList)
	end

	local function newLockHelper(key: string?): (DataStoreLockHelper.DataStoreLockHelper, DataStore.DataStore)
		local dataStore = newDataStore(key)
		local helper = maid:Add(DataStoreLockHelper.new(dataStore))
		return helper, dataStore
	end

	local function newMessageHelper(
		dataStore: DataStore.DataStore?
	): (DataStoreMessageHelper.DataStoreMessageHelper, DataStore.DataStore)
		local store = dataStore or newDataStore()
		return DataStoreTestUtils.newMessageHelper(maid, serviceBag, store), store
	end

	local function newServer(
		opts: ServerOptions?
	): (DataStore.DataStore, DataStoreMessageHelper.DataStoreMessageHelper?)
		local options: ServerOptions = opts or {}
		local dataStore = newSessionLockedStore(options.key)
		local helper
		if options.messaging then
			dataStore:SetSessionMessagingEnabled(true, serviceBag)
			helper = newMessageHelper(dataStore)
		end
		if options.autoCloseOnRequest then
			dataStore.SessionCloseRequested:Connect(function()
				dataStore:SaveAndCloseSession()
			end)
		end
		return dataStore, helper
	end

	local function awaitOwn(dataStore: DataStore.DataStore): boolean
		local promise = dataStore:PromiseLoadSuccessful()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			return false
		end
		local ok, loadedOk = promise:Yield()
		return ok and loadedOk == true
	end

	local controller: DataStoreTestController = {
		maid = maid,
		mock = mock,
		serviceBag = serviceBag,
		newDataStore = newDataStore,
		newSessionLockedStore = newSessionLockedStore,
		newLockHelper = newLockHelper,
		newMessageHelper = newMessageHelper,
		newServer = newServer,
		awaitOwn = awaitOwn,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

--[=[
	Builds a controller over a [PlayerDataStoreManager] backed by a fresh [DataStoreMock], keyed
	`user_<userId>`. `Destroy` closes the game before cleaning up.

	@return DataStoreManagerTestController
]=]
function DataStoreTestUtils.setupDataStoreManager(): DataStoreManagerTestController
	local maid = Maid.new()

	local mock = DataStoreMock.new()
	local serviceBag = DataStoreTestUtils.newServiceBag(maid)
	local bindToCloseService: BindToCloseService.BindToCloseService = serviceBag:GetService(BindToCloseService) :: any

	local manager: PlayerDataStoreManager.PlayerDataStoreManager =
		maid:Add(PlayerDataStoreManager.new(serviceBag, mock :: any, function(userId)
			return "user_" .. tostring(userId)
		end))

	-- Returns exactly one value: specs call this straight through expect(), which rejects a second arg.
	local function storeAndAwaitLock(): boolean
		local dataStore = assert(manager:GetDataStore(1), "No dataStore")
		dataStore:Store("coins", 5)
		-- The session-locked load acquires the lock (writes the envelope) before we remove.
		local raw = mock:GetRaw("user_1")
		return raw ~= nil and raw.lock ~= nil
	end

	local controller: DataStoreManagerTestController = {
		manager = manager,
		mock = mock,
		serviceBag = serviceBag,
		bindToCloseService = bindToCloseService,
		storeAndAwaitLock = storeAndAwaitLock,
		Destroy = function(_self)
			-- A loaded store's auto-save loop otherwise outlives the spec and fires in a later package's window.
			PromiseTestUtils.awaitFulfilled(bindToCloseService:PromiseClose())
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

--[=[
	Builds a started [ServiceBag] with PlaceMessagingService and [BindToCloseService], owned by the maid.

	@param maid Maid
	@param robloxMessagingService MessagingServiceMock? -- injected when provided
	@return ServiceBag
]=]
function DataStoreTestUtils.newServiceBag(
	maid: Maid.Maid,
	robloxMessagingService: MessagingServiceMock.MessagingServiceMock?
): ServiceBag.ServiceBag
	local serviceBag = maid:Add(ServiceBag.new())
	local placeMessagingService: PlaceMessagingService.PlaceMessagingService =
		serviceBag:GetService(PlaceMessagingService) :: any
	serviceBag:GetService(BindToCloseService)
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
function DataStoreTestUtils.newDataStore(
	maid: Maid.Maid,
	mock: DataStoreMock.DataStoreMock,
	key: string
): DataStore.DataStore
	return maid:Add(DataStore.new(mock :: any, key))
end

--[=[
	Builds a session-locked [DataStore] over `mock` and owns it with the maid.

	@param maid Maid
	@param mock DataStoreMock
	@param key string
	@param userIdList { number }? -- defaults to { 1 }
	@return DataStore
]=]
function DataStoreTestUtils.newSessionLockedStore(
	maid: Maid.Maid,
	mock: DataStoreMock.DataStoreMock,
	key: string,
	userIdList: { number }?
): DataStore.DataStore
	local dataStore = DataStoreTestUtils.newDataStore(maid, mock, key)
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
function DataStoreTestUtils.newMessageHelper(
	maid: Maid.Maid,
	serviceBag: ServiceBag.ServiceBag,
	dataStore: DataStore.DataStore
): DataStoreMessageHelper.DataStoreMessageHelper
	return maid:Add(DataStoreMessageHelper.new(serviceBag, dataStore))
end

return DataStoreTestUtils
