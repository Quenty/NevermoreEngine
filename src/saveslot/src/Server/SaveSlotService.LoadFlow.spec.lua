--!strict
--[[
	Characterizes the save-slot load flow -- the substore reads HasSaveSlots performs -- driven
	through a mock-injected PlayerDataStoreService. A headless cloud test server has no real Players
	to bind the PlayerBinder to, so these reproduce the load against the same datastore substore
	layout (SaveSlotConstants) with a numeric userId.

	@class SaveSlotService.LoadFlow.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID = 1

local function setup(mock: DataStoreMock.DataStoreMock?)
	local maid = Maid.new()
	local dataStoreMock = mock or DataStoreMock.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(dataStoreMock)
	serviceBag:Start()

	-- The manager hands back a datastore without loading it, so this resolves even when every
	-- request is set to fail -- the failure surfaces on the first read instead.
	local status, resolved = PromiseTestUtils.awaitOutcome(playerDataStoreService:PromiseDataStore(USER_ID), 10)
	assert(status == "resolved", `Failed to resolve the player data store ({status})`)

	local dataStore: DataStore.DataStore = resolved
	local systemStore = dataStore:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)

	local function Destroy(_self)
		-- The store the spec loaded is only destroyed by a removal, and a PlayerMock never fires the
		-- real Players.PlayerRemoving, so shut down the way Roblox does or its auto-save loop outlives
		-- this spec and fires inside a later package's window.
		DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
		maid:DoCleaning()
	end

	local controller = {
		mock = dataStoreMock,
		dataStore = dataStore,
		systemStore = systemStore,
		metadataStore = systemStore:GetSubStore(SaveSlotConstants.METADATA_STORE_KEY),
		getSlotStore = function(slotId: string)
			return systemStore:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY):GetSubStore(slotId)
		end,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("save slot load flow (healthy datastore)", function()
	it("loads empty slot metadata and no active slot for a fresh user", function()
		local controller = setup()

		local metadataStatus, metadata = PromiseTestUtils.awaitOutcome(controller.metadataStore:LoadAll({}), 10)
		expect(metadataStatus).toEqual("resolved")
		expect(metadata).toEqual({})

		local activeStatus, activeSlotId =
			PromiseTestUtils.awaitOutcome(controller.systemStore:Load("activeSlotId"), 10)
		expect(activeStatus).toEqual("resolved")
		expect(activeSlotId).toEqual(nil)

		controller:Destroy()
	end)

	it("round-trips a slot's data through the slot substore", function()
		local controller = setup()

		local slotStore = controller.getSlotStore("slot-abc")
		slotStore:Store("coins", 25)

		local saveStatus = PromiseTestUtils.awaitOutcome(controller.dataStore:Save(), 10)
		expect(saveStatus).toEqual("resolved")

		local loadStatus, coins = PromiseTestUtils.awaitOutcome(slotStore:Load("coins"), 10)
		expect(loadStatus).toEqual("resolved")
		expect(coins).toEqual(25)

		controller:Destroy()
	end)
end)

describe("save slot load flow (datastore down)", function()
	it("surfaces an error fast instead of hanging when datastores are down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local controller = setup(mock)

		local status = PromiseTestUtils.awaitOutcome(controller.metadataStore:LoadAll({}), 5)
		expect(status).toEqual("rejected")

		controller:Destroy()
	end)
end)
