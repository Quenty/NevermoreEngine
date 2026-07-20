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
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PromiseTestUtils = require("PromiseTestUtils")
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
	local function createAndSelect(context, slotIndex: number)
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

	local function getMetadata(context, slotId)
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
