--!strict
--[[
	The per-player load and selection chain (slots loaded -> teleport read -> default slot) runs against
	datastore reads that can settle long after the player left — session-lock and datastore
	retries outlive a leave. A continuation that then calls into the destroyed
	(metatable-stripped) HasSaveSlots binder throws "attempt to call missing method ..." as a
	stray error that fails the whole run. The chain must consume a late settle silently: every
	hop is maid-owned (cancelled with the binder's brio) and re-checks the binder is alive.

	@class SaveSlotService.LateSettle.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID = 636363
local EXISTING_SLOT_ID = "e6f0c1a2-late-settle"

-- Every datastore read yields this long, so the spec can land the unbind inside a chosen
-- read's in-flight window. Kept as short as the window can be while still spanning several frames:
-- these four tests otherwise spend their whole runtime waiting out real datastore latency, and the
-- window is guarded -- a read that has already settled fails the awaitSettled assertion before the
-- unbind, rather than quietly reducing the test to nothing.
local READ_YIELD_SECONDS = 0.15

local function setup()
	local maid = Maid.new()

	local mock = DataStoreMock.new()
	mock:SetYieldTime(READ_YIELD_SECONDS)

	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local hasSaveSlotsBinder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:GetService(require("SaveSlotService"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	local fakePlayer = maid:Add(PlayerMock.new({ UserId = USER_ID }))
	fakePlayer.Parent = Workspace

	local function Destroy(_self)
		-- The store the spec loaded is only destroyed by a removal, and a PlayerMock never fires the
		-- real Players.PlayerRemoving, so shut down the way Roblox does or its auto-save loop outlives
		-- this spec and fires inside a later package's window.
		DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
		serviceBag:Destroy()
		maid:DoCleaning()
		-- Any straggler continuation blows up here, inside the test that owns it, rather
		-- than as flake in a later suite.
		task.wait(READ_YIELD_SECONDS * 3)
	end

	local controller = {
		mock = mock,
		-- A returning player's persisted slot, written straight into the mock the way a previous
		-- session left it.
		seedExistingSlot = function()
			mock:SetRaw(tostring(USER_ID), {
				[SaveSlotConstants.SYSTEM_STORE_KEY] = {
					[SaveSlotConstants.METADATA_STORE_KEY] = {
						[EXISTING_SLOT_ID] = {
							SlotIndex = SaveSlotConstants.DEFAULT_SLOT_INDEX,
							SlotName = "Slot 1",
							CreatedTime = 1,
						},
					},
					activeSlotId = EXISTING_SLOT_ID,
				},
			})
		end,
		join = function()
			return assert(hasSaveSlotsBinder:Bind(fakePlayer), "Failed to bind HasSaveSlots")
		end,
		leave = function()
			hasSaveSlotsBinder:Unbind(fakePlayer)
		end,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("SaveSlotService selection chain vs a player who leaves mid-load", function()
	it("consumes a slots-load still pending when the binder dies", function()
		local controller = setup()

		local slotsLoaded = controller.join():PromiseSlotsLoaded()

		-- Let the service's chain attach to the (still pending) load, then "leave".
		task.wait()
		expect(PromiseTestUtils.awaitSettled(slotsLoaded, 0)).toEqual(false)
		controller.leave()

		controller:Destroy()
	end)

	-- Pins that seedExistingSlot really lands where the load reads it. Without this, drift in the raw
	-- layout would quietly reduce the late-settle test below to the empty-metadata case it exists to
	-- replace -- green, and no longer reaching _buildSlot at all.
	it("loads the seeded slot when the player stays", function()
		local controller = setup()
		controller.seedExistingSlot()

		local hasSaveSlots = controller.join()
		expect(PromiseTestUtils.awaitSettled(hasSaveSlots:PromiseSlotsLoaded(), 10)).toEqual(true)

		local hasSlotStatus, hasSlot = PromiseTestUtils.awaitOutcome(hasSaveSlots:PromiseHasSlot(EXISTING_SLOT_ID), 10)
		expect(hasSlotStatus).toEqual("resolved")
		expect(hasSlot).toEqual(true)

		-- Waiting on the selection itself, rather than PromiseLastActiveSlotId (which can answer from
		-- _lastActiveSlotId while the selection is still in flight), also quiesces the chain before teardown.
		expect(PromiseTestUtils.awaitValue(function()
			return hasSaveSlots.ActiveSlotId.Value == EXISTING_SLOT_ID
		end, 10)).toEqual(true)

		controller:Destroy()
	end)

	it("consumes a returning player's slots-load that settles after the binder died", function()
		local controller = setup()

		-- A returning player, so the load settles with metadata to build slots from. The empty-metadata
		-- case above never reaches _buildSlot, which is how a live server kept throwing there
		-- ("attempt to call missing method '_buildSlot'") while that test stayed green.
		controller.seedExistingSlot()

		local slotsLoaded = controller.join():PromiseSlotsLoaded()

		task.wait()
		expect(PromiseTestUtils.awaitSettled(slotsLoaded, 0)).toEqual(false)
		controller.leave()

		controller:Destroy()
	end)

	it("consumes a default-slot read that settles after the binder died", function()
		local controller = setup()

		local hasSaveSlots = controller.join()

		-- Play the chain forward to the default-slot resolution: slots loaded, teleport read
		-- consumed, and the last-active-slot datastore read now in its in-flight window.
		expect(PromiseTestUtils.awaitSettled(hasSaveSlots:PromiseSlotsLoaded(), 10)).toEqual(true)
		task.wait()

		-- The player leaves inside that window; the read settles after the binder is gone.
		-- With the regression, the settle's continuation calls the destroyed binder and a
		-- stray "attempt to call missing method" error fails the run.
		controller.leave()

		controller:Destroy()
	end)
end)
