--!strict
--[[
	Where a selection asks SaveSlotService whether it may proceed, and what it does with the answer. The
	fan-out behind that answer is covered in SaveSlotService.spec.

	@class HasSaveSlots.PreSelect.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local Workspace = game:GetService("Workspace")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424243

local activeContext: any = nil

afterEach(function()
	if activeContext then
		local context = activeContext
		activeContext = nil
		context.destroy()
	end
end)

type Ask = { slotId: string, previousSlotId: string? }

local function setup()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TeleportDataService"))
	serviceBag:GetService(require("SaveSlotSharedDataStoreService"))
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(DataStoreMock.new())
	serviceBag:Start()

	local fakePlayer = PlayerMock.new({ UserId = FAKE_USER_ID })
	fakePlayer.Parent = Workspace

	local hasSaveSlots = assert(binder:Bind(fakePlayer), "Failed to bind HasSaveSlots")
	hasSaveSlots.MaxSlotCount.Value = 5

	-- Booting SaveSlotService here would drag a second PlayerMockService into a DataModel another suite is
	-- already using one in, so the question put to it is answered by the test.
	local asks: { Ask } = {}
	local verdict: any = nil
	hasSaveSlots._promisePreSelectFromSaveSlotService = function(_self: any, slotId: string): any
		table.insert(asks, { slotId = slotId, previousSlotId = hasSaveSlots.ActiveSlotId.Value })

		return verdict or Promise.resolved(true)
	end

	local destroyed = false
	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		if activeContext and activeContext.destroy == destroy then
			activeContext = nil
		end

		-- The store the spec loaded is only destroyed by a removal, and a PlayerMock never fires the
		-- real Players.PlayerRemoving, so shut down the way Roblox does or its auto-save loop outlives
		-- this spec and fires inside a later package's window.
		DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end

	local context = {
		serviceBag = serviceBag,
		fakePlayer = fakePlayer,
		hasSaveSlots = hasSaveSlots,
		asks = asks,
		answerWith = function(promise: any)
			verdict = promise
		end,
		destroy = destroy,
	}
	activeContext = context

	return context
end

local function await(promise: any): any
	assert(PromiseTestUtils.awaitSettled(promise, 10), "promise never settled")
	local ok, value = promise:Yield()
	assert(ok, `promise rejected: {tostring(value)}`)
	return value
end

describe("HasSaveSlots pre-select", function()
	it("asks before the slot becomes active", function()
		local context = setup()

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(#context.asks).toEqual(1)
		expect(context.asks[1].slotId).toEqual(slotId)
		expect(context.asks[1].previousSlotId).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("reports the selection being replaced when switching slots", function()
		local context = setup()

		local firstId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local secondId = await(context.hasSaveSlots:PromiseCreateSlot(2))
		await(context.hasSaveSlots:PromiseSelectSlot(firstId))
		await(context.hasSaveSlots:PromiseSelectSlot(secondId))

		expect(#context.asks).toEqual(2)
		expect(context.asks[2].slotId).toEqual(secondId)
		expect(context.asks[2].previousSlotId).toEqual(firstId)

		context.destroy()
	end)

	it("asks for a new slot and for an ephemeral slot alike", function()
		local context = setup()

		local newId = await(context.hasSaveSlots:PromiseSelectNewSaveSlot())
		local ephemeralId = await(context.hasSaveSlots:PromiseSelectEphemeralSlot({ SlotName = "Throwaway" }))

		expect(#context.asks).toEqual(2)
		expect(context.asks[1].slotId).toEqual(newId)
		expect(context.asks[2].slotId).toEqual(ephemeralId)

		context.destroy()
	end)

	it("does not ask when the slot is already active", function()
		local context = setup()

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(#context.asks).toEqual(1)

		context.destroy()
	end)

	it("holds the selection until the answer settles", function()
		local context = setup()

		local gate = Promise.new()
		context.answerWith(gate)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local selection = context.hasSaveSlots:PromiseSelectSlot(slotId)

		expect(PromiseTestUtils.awaitSettled(selection, 0.5)).toEqual(false)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		gate:Resolve(true)

		await(selection)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("rejects the selection and leaves the active slot alone when refused", function()
		local context = setup()

		context.answerWith(Promise.resolved(false))

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local selection = context.hasSaveSlots:PromiseSelectSlot(slotId)

		assert(PromiseTestUtils.awaitSettled(selection, 10), "selection never settled")
		expect(selection:IsRejected()).toEqual(true)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("leaves the previous selection standing when a switch is refused", function()
		local context = setup()

		local firstId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local secondId = await(context.hasSaveSlots:PromiseCreateSlot(2))
		await(context.hasSaveSlots:PromiseSelectSlot(firstId))

		context.answerWith(Promise.resolved(false))
		local selection = context.hasSaveSlots:PromiseSelectSlot(secondId)

		assert(PromiseTestUtils.awaitSettled(selection, 10), "selection never settled")
		expect(selection:IsRejected()).toEqual(true)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(firstId)

		context.destroy()
	end)
end)
