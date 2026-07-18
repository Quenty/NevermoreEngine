--!nonstrict
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
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach
local jest = Jest.Globals.jest

local FAKE_USER_ID = 424242

-- Real implementation, captured at load so the spy can fall through for anything but the fake player.
local originalToUserId = PlayerDataStoreManager._toPlayerUserIdOrError

afterEach(function()
	jest.restoreAllMocks()
end)

local function setup(mock)
	mock = mock or DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	local playerDataStoreService = serviceBag:GetService(require("PlayerDataStoreService"))
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(mock)
	serviceBag:Start()

	local fakePlayer = Instance.new("Folder")
	fakePlayer.Name = "FakePlayer"
	fakePlayer.Parent = Workspace

	-- Intercept only the UserId read so a Folder can stand in for a Player. Restored after each test.
	jest.spyOn(PlayerDataStoreManager, "_toPlayerUserIdOrError").mockImplementation(function(self, playerOrUserId)
		if playerOrUserId == fakePlayer then
			return FAKE_USER_ID
		end
		return originalToUserId(self, playerOrUserId)
	end)

	local hasSaveSlots = binder:Bind(fakePlayer)
	if hasSaveSlots then
		hasSaveSlots.MaxSlotCount.Value = 5
	end

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
