--!strict
--[[
	Integration coverage for the real HasSaveSlots binder, driven against a mocked datastore. Because
	the load path only reads the player's UserId, a plain Folder stands in for a Player with
	PlayerDataStoreManager._toPlayerUserIdOrError intercepted to map it to a fixed userId; everything
	else exercises the real code.

	@class HasSaveSlots.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Observable = require("Observable")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PromiseTestUtils = require("PromiseTestUtils")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

local FAKE_USER_ID = 424242

-- Real implementation, captured at load so the patch can fall through for anything but the fake player.
local originalToUserId = PlayerDataStoreManager._toPlayerUserIdOrError

-- We monkeypatch _toPlayerUserIdOrError directly rather than jest.spyOn: after jest.restoreAllMocks(),
-- re-spying the same method on the next test is a no-op (spyOn hands back the stale, already-restored
-- spy without re-patching the object), so only the first test's spy took effect and every later Bind
-- threw "Bad playerOrUserId". A direct swap re-patches deterministically each setup.
afterEach(function()
	PlayerDataStoreManager._toPlayerUserIdOrError = originalToUserId
end)

local function setup(mock: DataStoreMock.DataStoreMock?)
	mock = mock or DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TeleportDataService"))
	-- GetService returns the required module's type; PlayerDataStoreService returns its class table, so
	-- cast to the instance type before calling instance methods.
	local playerDataStoreService = (
		serviceBag:GetService(PlayerDataStoreService) :: any
	) :: PlayerDataStoreService.PlayerDataStoreService
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	-- A Folder stands in for a Player; the load path only reads the UserId, intercepted below.
	local fakePlayer = (Instance.new("Folder") :: any) :: Player
	fakePlayer.Name = "FakePlayer"
	fakePlayer.Parent = Workspace

	-- Intercept only the UserId read so a Folder can stand in for a Player. Restored after each test.
	PlayerDataStoreManager._toPlayerUserIdOrError = function(self, playerOrUserId)
		if playerOrUserId == fakePlayer then
			return FAKE_USER_ID
		end
		return originalToUserId(self, playerOrUserId)
	end

	local hasSaveSlots = assert(binder:Bind(fakePlayer), "Failed to bind HasSaveSlots")
	hasSaveSlots.MaxSlotCount.Value = 5

	local function destroy()
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end

	return {
		serviceBag = serviceBag,
		binder = binder,
		fakePlayer = fakePlayer,
		hasSaveSlots = hasSaveSlots,
		mock = mock,
		destroy = destroy,
	}
end

describe("HasSaveSlots against a fake player (healthy datastore)", function()
	it("should construct via the binder and load slots for a fresh player", function()
		local context = setup()
		expect(context.hasSaveSlots).never.toBeNil()

		local promise = context.hasSaveSlots:PromiseSlotsLoaded()
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("slots load hung").toEqual("slots load settled")
			context.destroy()
			return
		end
		expect((promise:Yield())).toEqual(true)

		context.destroy()
	end)

	it("should create a slot and find it", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local ok, slotId = createPromise:Yield()
		expect(ok).toEqual(true)
		expect(type(slotId)).toEqual("string")

		local hasPromise = context.hasSaveSlots:PromiseHasSlot(slotId)
		if not PromiseTestUtils.awaitSettled(hasPromise, 10) then
			expect("hasSlot hung").toEqual("hasSlot settled")
			context.destroy()
			return
		end
		expect((hasPromise:Wait())).toEqual(true)

		local indexPromise = context.hasSaveSlots:PromiseSlotIdFromIndex(1)
		if not PromiseTestUtils.awaitSettled(indexPromise, 10) then
			expect("slotIdFromIndex hung").toEqual("slotIdFromIndex settled")
			context.destroy()
			return
		end
		expect((indexPromise:Wait())).toEqual(slotId)

		context.destroy()
	end)

	it("should select a slot and report it active", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		expect((selectPromise:Yield())).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toEqual(slotId)

		context.destroy()
	end)

	it("should observe the active slot store after selection", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local capturedStore
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				capturedStore = brio:GetValue()
			end
		end)

		local emitted = PromiseTestUtils.awaitValue(function()
			return capturedStore ~= nil
		end, 10)
		subscription:Destroy()

		expect(emitted).toEqual(true)

		context.destroy()
	end)

	it("ObserveActiveSlotStoreBrio tears its brio down once the active slot is deselected", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local activeBrio: any = nil
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				activeBrio = brio
			end
		end)

		local emitted = PromiseTestUtils.awaitValue(function()
			return activeBrio ~= nil
		end, 10)
		expect(emitted).toEqual(true)
		expect(activeBrio:IsDead()).toEqual(false)

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			subscription:Destroy()
			context.destroy()
			return
		end
		deselectPromise:Yield()

		-- The store observable kills its brio when the slot is cleared. This is the reactive teardown the
		-- game relies on: on deselect the server unbinds per-slot data and removes the character purely
		-- because this brio dies -- no bespoke deselect handling.
		expect(activeBrio:IsDead()).toEqual(true)

		subscription:Destroy()
		context.destroy()
	end)

	it("ObserveActiveSlotStoreBrio swaps its brio when switching to another slot", function()
		local context = setup()

		local firstCreate = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstCreate, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		local _, firstSlotId = firstCreate:Yield()

		local secondCreate = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(secondCreate, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		local _, secondSlotId = secondCreate:Yield()

		local selectFirst = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(selectFirst, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectFirst:Yield()

		local currentBrio: any = nil
		local subscription = context.hasSaveSlots:ObserveActiveSlotStoreBrio():Subscribe(function(brio)
			if not brio:IsDead() then
				currentBrio = brio
			end
		end)

		if not PromiseTestUtils.awaitValue(function()
			return currentBrio ~= nil
		end, 10) then
			expect("first brio hung").toEqual("first brio emitted")
			subscription:Destroy()
			context.destroy()
			return
		end
		local firstBrio = currentBrio

		local selectSecond = context.hasSaveSlots:PromiseSelectSlot(secondSlotId)
		if not PromiseTestUtils.awaitSettled(selectSecond, 10) then
			expect("switch hung").toEqual("switch settled")
			subscription:Destroy()
			context.destroy()
			return
		end
		selectSecond:Yield()

		if not PromiseTestUtils.awaitValue(function()
			return currentBrio ~= firstBrio
		end, 10) then
			expect("second brio hung").toEqual("second brio emitted")
			subscription:Destroy()
			context.destroy()
			return
		end

		-- Switching slots kills the old slot's store brio and emits a fresh one, so per-slot server state
		-- (data bindings, checkpoints, the character) rebuilds against the newly-selected slot.
		expect(firstBrio:IsDead()).toEqual(true)
		expect(currentBrio:IsDead()).toEqual(false)

		subscription:Destroy()
		context.destroy()
	end)

	it("should reject creating a slot beyond the max slot count", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = 1

		local promise = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		expect((promise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("should reject creating a duplicate slot index", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		firstPromise:Yield()

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		expect((secondPromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("should reject deleting the active slot", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotId)
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		expect((deletePromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("should replicate the last active slot after selection", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("PromiseDeselectSlot clears the active slot but remembers the last active", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		expect((deselectPromise:Yield())).toEqual(true)

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		-- The slot is deselected, not deleted: the last-active pointer still resolves it
		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toEqual(slotId)

		context.destroy()
	end)

	it("deleting the last-active slot clears the continue pointer", function()
		-- Repro for the `delete-save-slot *` bug: deleting the (deselected) active slot left
		-- LastActiveSlotId dangling, so the menu kept offering "Continue" for a slot that was gone.
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		-- Deselect first, matching how the cmdr command frees the active slot before deleting it.
		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()

		-- Deselection deliberately keeps remembering the slot for "Continue"...
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotId)
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		deletePromise:Yield()

		-- ...but once that slot is deleted, there is nothing to continue on.
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toBeNil()

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("deleting a non-last-active slot leaves the continue pointer intact", function()
		-- The clear must be scoped to the resumable slot: deleting some other slot must not wipe it.
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		local _, firstSlotId = firstPromise:Yield()

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		local _, secondSlotId = secondPromise:Yield()

		-- Slot 1 is the last-active; slot 2 is just another slot, and stays deletable while 1 is deselected.
		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()

		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(secondSlotId)
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		deletePromise:Yield()

		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(firstSlotId)

		context.destroy()
	end)

	it("PromiseDeselectSlot is a no-op when no slot is active", function()
		local context = setup()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		expect((deselectPromise:Yield())).toEqual(true)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("PromiseDeselectSlot then PromiseSelectLastSaveSlot round-trips back into the slot", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		local continuePromise = context.hasSaveSlots:PromiseSelectLastSaveSlot()
		if not PromiseTestUtils.awaitSettled(continuePromise, 10) then
			expect("continue hung").toEqual("continue settled")
			context.destroy()
			return
		end
		expect((continuePromise:Wait())).toEqual(slotId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("PromiseSelectLastSaveSlot re-selects the last active slot after the active slot is cleared", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		-- Simulate returning to the menu: no active slot, but the last active is remembered
		context.hasSaveSlots.ActiveSlotId.Value = nil
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local continuePromise = context.hasSaveSlots:PromiseSelectLastSaveSlot()
		if not PromiseTestUtils.awaitSettled(continuePromise, 10) then
			expect("continue hung").toEqual("continue settled")
			context.destroy()
			return
		end
		expect((continuePromise:Wait())).toEqual(slotId)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("PromiseSelectLastSaveSlot resolves nil when there is nothing to continue", function()
		local context = setup()

		local continuePromise = context.hasSaveSlots:PromiseSelectLastSaveSlot()
		if not PromiseTestUtils.awaitSettled(continuePromise, 10) then
			expect("continue hung").toEqual("continue settled")
			context.destroy()
			return
		end
		expect((continuePromise:Wait())).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("PromiseSelectNewSaveSlot creates and selects a fresh slot each time", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("new game hung").toEqual("new game settled")
			context.destroy()
			return
		end
		local firstSlotId = firstPromise:Wait()
		expect(type(firstSlotId)).toEqual("string")
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(firstSlotId)

		local secondPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second new game hung").toEqual("second new game settled")
			context.destroy()
			return
		end
		local secondSlotId = secondPromise:Wait()
		expect(type(secondSlotId)).toEqual("string")
		expect(secondSlotId ~= firstSlotId).toEqual(true)

		context.destroy()
	end)

	it("PromiseDeleteAllSlots wipes every slot and clears the selection", function()
		local context = setup()

		local firstPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(firstPromise, 10) then
			expect("first create hung").toEqual("first create settled")
			context.destroy()
			return
		end
		local _, firstSlotId = firstPromise:Yield()

		local secondPromise = context.hasSaveSlots:PromiseCreateSlot(2)
		if not PromiseTestUtils.awaitSettled(secondPromise, 10) then
			expect("second create hung").toEqual("second create settled")
			context.destroy()
			return
		end
		secondPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local wipePromise = context.hasSaveSlots:PromiseDeleteAllSlots()
		if not PromiseTestUtils.awaitSettled(wipePromise, 10) then
			expect("wipe hung").toEqual("wipe settled")
			context.destroy()
			return
		end
		wipePromise:Yield()

		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toBeNil()

		local hasPromise = context.hasSaveSlots:PromiseHasSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(hasPromise, 10) then
			expect("hasSlot hung").toEqual("hasSlot settled")
			context.destroy()
			return
		end
		expect((hasPromise:Wait())).toEqual(false)

		context.destroy()
	end)

	it("PromiseSelectNewSaveSlot reuses the lowest free index after a deletion", function()
		local context = setup()

		-- Fill indices 1, 2, 3 (nothing is selected, so all remain deletable)
		local slotIdsByIndex = {}
		for index = 1, 3 do
			local createPromise = context.hasSaveSlots:PromiseCreateSlot(index)
			if not PromiseTestUtils.awaitSettled(createPromise, 10) then
				expect("create hung").toEqual("create settled")
				context.destroy()
				return
			end
			local _, slotId = createPromise:Yield()
			slotIdsByIndex[index] = slotId
		end

		-- Open a gap at index 2
		local deletePromise = context.hasSaveSlots:PromiseDeleteSlot(slotIdsByIndex[2])
		if not PromiseTestUtils.awaitSettled(deletePromise, 10) then
			expect("delete hung").toEqual("delete settled")
			context.destroy()
			return
		end
		deletePromise:Yield()

		-- The next new slot fills the gap at 2 rather than appending at 4
		local newPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
		if not PromiseTestUtils.awaitSettled(newPromise, 10) then
			expect("new game hung").toEqual("new game settled")
			context.destroy()
			return
		end
		local newSlotId = newPromise:Wait()
		expect(type(newSlotId)).toEqual("string")

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		expect((metadataPromise:Wait()).SlotIndex).toEqual(2)

		context.destroy()
	end)

	it("PromiseDuplicateSlot copies saved data into a fresh slot and marks the name", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1, { SlotName = "Adventure" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		-- Seed the source slot with some saved data to copy across
		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 500)

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot(slotId)
		if not PromiseTestUtils.awaitSettled(duplicatePromise, 10) then
			expect("duplicate hung").toEqual("duplicate settled")
			context.destroy()
			return
		end
		local newSlotId = duplicatePromise:Wait()
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= slotId).toEqual(true)

		-- The copy lands at the next free index with a marked name
		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		local metadata = metadataPromise:Wait()
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure (Copy)")

		-- The saved data carried across into the new slot's own store
		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toEqual(500)

		context.destroy()
	end)

	it("PromiseDuplicateSlot into the default slot preserves the system store", function()
		local context = setup()

		-- Only a non-default slot exists, so the duplicate lands at the free default index (1), whose
		-- store is the shared root alongside the SaveSlots system data.
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Save" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 750)

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot(slotId)
		if not PromiseTestUtils.awaitSettled(duplicatePromise, 10) then
			expect("duplicate hung").toEqual("duplicate settled")
			context.destroy()
			return
		end
		local newSlotId = duplicatePromise:Wait()

		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		expect((metadataPromise:Wait()).SlotIndex).toEqual(1)

		-- The original slot still resolves -- merging into root did not clobber the system store
		local sourceStillThere = context.hasSaveSlots:PromiseSlotIdFromIndex(2)
		if not PromiseTestUtils.awaitSettled(sourceStillThere, 10) then
			expect("lookup hung").toEqual("lookup settled")
			context.destroy()
			return
		end
		expect((sourceStillThere:Wait())).toEqual(slotId)

		-- The copied game data landed in the default (root) store
		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toEqual(750)

		context.destroy()
	end)

	it("PromiseDuplicateSlot rejects when the source slot is missing", function()
		local context = setup()

		local duplicatePromise = context.hasSaveSlots:PromiseDuplicateSlot("does-not-exist")
		if not PromiseTestUtils.awaitSettled(duplicatePromise, 10) then
			expect("duplicate hung").toEqual("duplicate settled")
			context.destroy()
			return
		end
		expect((duplicatePromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("PromiseResetActiveSlot wipes saved data but keeps the slot's index and name", function()
		local context = setup()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Adventure" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		-- Seed the active slot with saved progress the reset must clear
		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 500)

		local resetPromise = context.hasSaveSlots:PromiseResetActiveSlot()
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= slotId).toEqual(true)

		-- The fresh slot is selected and the old one is gone
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(newSlotId)
		local hasOldPromise = context.hasSaveSlots:PromiseHasSlot(slotId)
		if not PromiseTestUtils.awaitSettled(hasOldPromise, 10) then
			expect("hasSlot hung").toEqual("hasSlot settled")
			context.destroy()
			return
		end
		expect((hasOldPromise:Wait())).toEqual(false)

		-- Same index and name carried across into the fresh slot
		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		local metadata = metadataPromise:Wait()
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure")

		-- The saved progress did not survive into the fresh slot's store
		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("PromiseResetActiveSlot resets the default slot in place, preserving the system store", function()
		local context = setup()

		-- Index 1 is the default slot, whose store is the shared root alongside the SaveSlots
		-- system data; the reset must wipe the game data without clobbering that system store.
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1, { SlotName = "Save" })
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(slotId):Store("Coins", 750)

		local resetPromise = context.hasSaveSlots:PromiseResetActiveSlot()
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()

		-- The system store survived: the fresh default slot still resolves at index 1
		local lookupPromise = context.hasSaveSlots:PromiseSlotIdFromIndex(1)
		if not PromiseTestUtils.awaitSettled(lookupPromise, 10) then
			expect("lookup hung").toEqual("lookup settled")
			context.destroy()
			return
		end
		expect((lookupPromise:Wait())).toEqual(newSlotId)

		-- The game data in the shared root store was wiped
		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("PromiseResetActiveSlot is a no-op resolving nil when no slot is active", function()
		local context = setup()

		local resetPromise = context.hasSaveSlots:PromiseResetActiveSlot()
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		expect((resetPromise:Wait())).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("PromiseResetSlot wipes a non-active slot without touching the active selection", function()
		local context = setup()

		-- Slot 1 is active; slot 2 is the one we reset and must stay unselected throughout.
		local activePromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(activePromise, 10) then
			expect("active create hung").toEqual("active create settled")
			context.destroy()
			return
		end
		local _, activeSlotId = activePromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(activeSlotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local targetPromise = context.hasSaveSlots:PromiseCreateSlot(2, { SlotName = "Adventure" })
		if not PromiseTestUtils.awaitSettled(targetPromise, 10) then
			expect("target create hung").toEqual("target create settled")
			context.destroy()
			return
		end
		local _, targetSlotId = targetPromise:Yield()

		local tracker: any = context.hasSaveSlots
		tracker:_getSlotStore(targetSlotId):Store("Coins", 500)

		local resetPromise = context.hasSaveSlots:PromiseResetSlot(targetSlotId)
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()
		expect(type(newSlotId)).toEqual("string")
		expect(newSlotId ~= targetSlotId).toEqual(true)

		-- The active slot is untouched and the fresh slot is not selected
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(activeSlotId)

		-- Same index and name carried across; saved progress was wiped
		local metadataPromise = context.hasSaveSlots:PromiseGetSlotMetadata(newSlotId)
		if not PromiseTestUtils.awaitSettled(metadataPromise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			context.destroy()
			return
		end
		local metadata = metadataPromise:Wait()
		expect(metadata.SlotIndex).toEqual(2)
		expect(metadata.SlotName).toEqual("Adventure")

		local dataPromise = tracker:_getSlotStore(newSlotId):Load("Coins")
		if not PromiseTestUtils.awaitSettled(dataPromise, 10) then
			expect("data hung").toEqual("data settled")
			context.destroy()
			return
		end
		expect((dataPromise:Wait())).toBeNil()

		context.destroy()
	end)

	it("PromiseResetSlot keeps the continue pointer on the reset slot when it was last-active", function()
		local context = setup()

		-- Select then deselect so the slot is the resumable last-active but no longer selected.
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			context.destroy()
			return
		end
		selectPromise:Yield()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(slotId)

		local resetPromise = context.hasSaveSlots:PromiseResetSlot(slotId)
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		local newSlotId = resetPromise:Wait()

		-- The resume pointer follows the reset slot to its fresh id, and "Continue" still resolves it
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()
		expect(context.hasSaveSlots.LastActiveSlotId.Value).toEqual(newSlotId)

		local lastPromise = context.hasSaveSlots:PromiseLastActiveSlotId()
		if not PromiseTestUtils.awaitSettled(lastPromise, 10) then
			expect("lastActive hung").toEqual("lastActive settled")
			context.destroy()
			return
		end
		expect((lastPromise:Wait())).toEqual(newSlotId)

		context.destroy()
	end)

	it("PromiseResetSlot rejects when the slot is missing", function()
		local context = setup()

		local resetPromise = context.hasSaveSlots:PromiseResetSlot("does-not-exist")
		if not PromiseTestUtils.awaitSettled(resetPromise, 10) then
			expect("reset hung").toEqual("reset settled")
			context.destroy()
			return
		end
		expect((resetPromise:Yield())).toEqual(false)

		context.destroy()
	end)

	it("allows creating a slot past a finite cap when the count is unbounded", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = math.huge

		-- Index 6 is beyond the setup's finite cap of 5; unbounded must accept it
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(6)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local ok, slotId = createPromise:Yield()
		expect(ok).toEqual(true)
		expect(type(slotId)).toEqual("string")

		context.destroy()
	end)

	it("PromiseSelectNewSaveSlot never runs out of slots when unbounded", function()
		local context = setup()
		context.hasSaveSlots.MaxSlotCount.Value = math.huge

		-- Allocate past the finite cap of 5; every call still yields a fresh slot
		for _ = 1, 7 do
			local newPromise = context.hasSaveSlots:PromiseSelectNewSaveSlot()
			if not PromiseTestUtils.awaitSettled(newPromise, 10) then
				expect("new game hung").toEqual("new game settled")
				context.destroy()
				return
			end
			expect(type(newPromise:Wait())).toEqual("string")
		end

		context.destroy()
	end)
end)

describe("HasSaveSlots playtime tracking", function()
	local function createAndSelect(context: any, slotIndex: number): any
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(slotIndex)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			return nil
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			expect("select hung").toEqual("select settled")
			return nil
		end
		selectPromise:Yield()

		return slotId
	end

	local function getMetadata(context: any, slotId): any
		local promise = context.hasSaveSlots:PromiseGetSlotMetadata(slotId)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			expect("metadata hung").toEqual("metadata settled")
			return nil
		end
		return promise:Wait()
	end

	it("increments PlayCount to 1 the first time a slot is selected", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)
		expect(getMetadata(context, slotId).PlayCount).toEqual(1)

		context.destroy()
	end)

	it("counts a fresh session each time a slot is re-selected", function()
		local context = setup()

		local firstSlotId = createAndSelect(context, 1)
		local secondSlotId = createAndSelect(context, 2)

		-- Returning to the first slot is a second session for it, a first for the second slot
		local reselectPromise = context.hasSaveSlots:PromiseSelectSlot(firstSlotId)
		if not PromiseTestUtils.awaitSettled(reselectPromise, 10) then
			expect("reselect hung").toEqual("reselect settled")
			context.destroy()
			return
		end
		reselectPromise:Yield()

		expect(getMetadata(context, firstSlotId).PlayCount).toEqual(2)
		expect(getMetadata(context, secondSlotId).PlayCount).toEqual(1)

		context.destroy()
	end)

	it("accrues elapsed wall time into TimePlayed and LastSessionLength for the active slot", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		-- Rewind the live session's clock so a flush observes ~120s elapsed without waiting on it. The
		-- flush adds now - lastFlush, so the total is >= 120 (real time may nudge it a second higher).
		local tracker: any = context.hasSaveSlots
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		local metadata = getMetadata(context, slotId)
		expect(metadata.TimePlayed ~= nil and metadata.TimePlayed >= 120).toEqual(true)
		expect(metadata.LastSessionLength ~= nil and metadata.LastSessionLength >= 120).toEqual(true)

		context.destroy()
	end)

	it("does not accrue time before any slot is selected", function()
		local context = setup()

		-- No active slot -> the session is closed, so a flush lands nowhere
		local tracker: any = context.hasSaveSlots
		tracker:_flushPlaytime()

		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			expect("create hung").toEqual("create settled")
			context.destroy()
			return
		end
		local _, slotId = createPromise:Yield()

		expect(getMetadata(context, slotId).TimePlayed).toBeNil()

		context.destroy()
	end)

	it("stops accruing into a slot once it is deselected", function()
		local context = setup()

		local slotId = createAndSelect(context, 1)

		local tracker: any = context.hasSaveSlots
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()

		local deselectPromise = context.hasSaveSlots:PromiseDeselectSlot()
		if not PromiseTestUtils.awaitSettled(deselectPromise, 10) then
			expect("deselect hung").toEqual("deselect settled")
			context.destroy()
			return
		end
		deselectPromise:Yield()

		local afterDeselect = getMetadata(context, slotId).TimePlayed

		-- A flush after deselection lands nowhere: the session is closed, so the total must not move
		tracker._playSessionStart = os.time() - 120
		tracker._playSessionLastFlush = os.time() - 120
		tracker:_flushPlaytime()
		expect(getMetadata(context, slotId).TimePlayed).toEqual(afterDeselect)

		context.destroy()
	end)
end)

describe("HasSaveSlots summary providers", function()
	-- Selecting a slot drives the reactive summary aggregation; poll the slot metadata until the
	-- Summary settles into the expected shape.
	local function readSummary(context: any, slotId): any
		local promise = context.hasSaveSlots:PromiseGetSlotMetadata(slotId)
		if not PromiseTestUtils.awaitSettled(promise, 10) then
			return nil
		end
		local metadata = promise:Wait()
		return metadata and metadata.Summary
	end

	local function awaitSummary(context: any, slotId, predicate: (any) -> boolean): (boolean, any)
		local last
		local ok = PromiseTestUtils.awaitValue(function()
			last = readSummary(context, slotId)
			return last ~= nil and predicate(last)
		end, 10)
		return ok, last
	end

	local function createAndSelect(context: any): any
		local createPromise = context.hasSaveSlots:PromiseCreateSlot(1)
		if not PromiseTestUtils.awaitSettled(createPromise, 10) then
			return nil
		end
		local _, slotId = createPromise:Yield()

		local selectPromise = context.hasSaveSlots:PromiseSelectSlot(slotId)
		if not PromiseTestUtils.awaitSettled(selectPromise, 10) then
			return nil
		end
		selectPromise:Yield()

		return slotId
	end

	it("aggregates every registered provider into the Summary, keyed by name", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(100)
		end)
		context.hasSaveSlots:RegisterSummaryProvider("world", function()
			return Rx.of(3)
		end)

		local slotId = createAndSelect(context)
		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.coins == 100 and s.world == 3
		end)

		expect(matched).toEqual(true)
		expect(summary.coins).toEqual(100)
		expect(summary.world).toEqual(3)

		context.destroy()
	end)

	it("drops a provider's key from the Summary once it is unregistered", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(100)
		end)
		local unregisterWorld = context.hasSaveSlots:RegisterSummaryProvider("world", function()
			return Rx.of(3)
		end)

		local slotId = createAndSelect(context)
		expect((awaitSummary(context, slotId, function(s)
			return s.coins == 100 and s.world == 3
		end))).toEqual(true)

		unregisterWorld()

		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.coins == 100 and s.world == nil
		end)
		expect(matched).toEqual(true)
		expect(summary.world).toBeNil()

		context.destroy()
	end)

	it("isolates a provider that errors when called so the others still contribute", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("good", function()
			return Rx.of(1)
		end)
		context.hasSaveSlots:RegisterSummaryProvider("bad", function()
			error("provider boom")
		end)

		local slotId = createAndSelect(context)
		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.good == 1
		end)

		expect(matched).toEqual(true)
		expect(summary.bad).toBeNil()

		context.destroy()
	end)

	it("isolates a provider whose stream fails so the others still contribute", function()
		local context = setup()

		context.hasSaveSlots:RegisterSummaryProvider("good", function()
			return Rx.of(1)
		end)
		context.hasSaveSlots:RegisterSummaryProvider("bad", function()
			return Observable.new(function(sub)
				sub:Fail("stream boom")
				return nil
			end)
		end)

		local slotId = createAndSelect(context)
		local matched, summary = awaitSummary(context, slotId, function(s)
			return s.good == 1
		end)

		expect(matched).toEqual(true)
		expect(summary.bad).toBeNil()

		context.destroy()
	end)

	it("clears the Summary when every provider is unregistered", function()
		local context = setup()

		local unregister = context.hasSaveSlots:RegisterSummaryProvider("coins", function()
			return Rx.of(100)
		end)

		local slotId = createAndSelect(context)
		expect((awaitSummary(context, slotId, function(s)
			return s.coins == 100
		end))).toEqual(true)

		unregister()

		local cleared = PromiseTestUtils.awaitValue(function()
			return readSummary(context, slotId) == nil
		end, 10)
		expect(cleared).toEqual(true)

		context.destroy()
	end)
end)

describe("HasSaveSlots against a fake player (datastore down)", function()
	it("PromiseSlotsLoaded rejects fast instead of hanging when datastores are down", function()
		local mock = DataStoreMock.new()
		mock:FailAllRequests()

		local context = setup(mock)
		expect(context.hasSaveSlots).never.toBeNil()

		local promise = context.hasSaveSlots:PromiseSlotsLoaded()
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)

		if not promise:IsPending() then
			local ok = promise:Yield()
			expect(ok).toEqual(false)
		end

		context.destroy()
	end)
end)
