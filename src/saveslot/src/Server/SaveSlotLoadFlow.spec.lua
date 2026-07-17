--!nonstrict
--[[
	Characterizes the save-slot load flow -- the substore reads HasSaveSlots performs -- driven
	through a mock-injected PlayerDataStoreService. A headless cloud test server has no real Players
	to bind the PlayerBinder to, so these reproduce the load against the same datastore substore
	layout (SaveSlotConstants) with a numeric userId.

	@class SaveSlotLoadFlow.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a ServiceBag with a mock-injected PlayerDataStoreService, mirroring how the save-slot
-- system resolves a player's datastore.
local function newHarness(mock)
	local serviceBag = ServiceBag.new()
	local playerDataStoreService = serviceBag:GetService(require("PlayerDataStoreService"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()
	return playerDataStoreService, serviceBag
end

-- Resolves the session-locked datastore for a userId (bounded); returns nil on failure to settle.
local function resolveDataStore(playerDataStoreService, userId)
	local promise = playerDataStoreService:PromiseDataStore(userId)
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		return nil
	end
	local ok, dataStore = promise:Yield()
	if not ok then
		return nil
	end
	return dataStore
end

describe("save slot load flow (healthy datastore)", function()
	it("loads empty slot metadata and no active slot for a fresh user", function()
		local mock = DataStoreMock.new()
		local playerDataStoreService, serviceBag = newHarness(mock)

		local dataStore = resolveDataStore(playerDataStoreService, 1)
		expect(dataStore).never.toBeNil()

		local systemStore = dataStore:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)
		local metadataStore = systemStore:GetSubStore(SaveSlotConstants.METADATA_STORE_KEY)

		local metaPromise = metadataStore:LoadAll({})
		if not PromiseTestUtils.awaitSettled(metaPromise, 10) then
			expect("metadata load hung").toEqual("metadata load settled")
			serviceBag:Destroy()
			return
		end
		local metaOk, metadata = metaPromise:Yield()
		expect(metaOk).toEqual(true)
		expect(metadata).toEqual({})

		local activePromise = systemStore:Load("activeSlotId")
		if not PromiseTestUtils.awaitSettled(activePromise, 10) then
			expect("activeSlotId load hung").toEqual("activeSlotId load settled")
			serviceBag:Destroy()
			return
		end
		local activeOk, activeSlotId = activePromise:Yield()
		expect(activeOk).toEqual(true)
		expect(activeSlotId).toEqual(nil)

		serviceBag:Destroy()
	end)

	it("round-trips a slot's data through the slot substore", function()
		local mock = DataStoreMock.new()
		local playerDataStoreService, serviceBag = newHarness(mock)

		local dataStore = resolveDataStore(playerDataStoreService, 1)
		expect(dataStore).never.toBeNil()

		-- Slot stores live at SaveSlots.slots.<slotId>, matching HasSaveSlots._getSlotStore.
		local slotStore = dataStore
			:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)
			:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY)
			:GetSubStore("slot-abc")

		slotStore:Store("coins", 25)

		local savePromise = dataStore:Save()
		if not PromiseTestUtils.awaitSettled(savePromise, 10) then
			expect("save hung").toEqual("save settled")
			serviceBag:Destroy()
			return
		end
		expect((savePromise:Yield())).toEqual(true)

		local loadPromise = slotStore:Load("coins")
		if not PromiseTestUtils.awaitSettled(loadPromise, 10) then
			expect("load hung").toEqual("load settled")
			serviceBag:Destroy()
			return
		end
		local ok, value = loadPromise:Yield()
		expect(ok).toEqual(true)
		expect(value).toEqual(25)

		serviceBag:Destroy()
	end)
end)

describe("save slot load flow (datastore down)", function()
	it("surfaces an error fast instead of hanging when datastores are down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local playerDataStoreService, serviceBag = newHarness(mock)

		-- The manager hands back a datastore without loading, so this resolves.
		local dataStore = resolveDataStore(playerDataStoreService, 1)
		expect(dataStore).never.toBeNil()

		-- The first actual read (loading slot metadata) triggers the session-locked load.
		local metadataStore =
			dataStore:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY):GetSubStore(SaveSlotConstants.METADATA_STORE_KEY)

		local promise = metadataStore:LoadAll({})
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)

		if not promise:IsPending() then
			local ok = promise:Yield()
			expect(ok).toEqual(false)
		end

		serviceBag:Destroy()
	end)
end)
