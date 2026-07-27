--!strict
--[[
	Coverage for the pre-select callback: the seam a consumer uses to settle per-selection state before a
	slot becomes active, whatever selected it.

	@class HasSaveSlots.PreSelect.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
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

	-- The seam SaveSlotService fills on bind. Booting the service here would drag a second
	-- PlayerMockService into a DataModel another suite is already using one in.
	local callbacks: { any } = {}
	hasSaveSlots:SetPreSelectCallbackProvider(function(): { any }
		return table.clone(callbacks)
	end)

	local function register(callback: any): () -> ()
		table.insert(callbacks, callback)
		return function()
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end
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

		fakePlayer:Destroy()
		serviceBag:Destroy()
	end

	local context = {
		serviceBag = serviceBag,
		fakePlayer = fakePlayer,
		hasSaveSlots = hasSaveSlots,
		register = register,
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

type Call = { player: Player, slotId: string, previousSlotId: string?, activeAtCall: string? }

local function recordCalls(context: any): { Call }
	local calls: { Call } = {}

	context.register(function(player: Player, slotId: string, previousSlotId: string?)
		table.insert(calls, {
			player = player,
			slotId = slotId,
			previousSlotId = previousSlotId,
			activeAtCall = context.hasSaveSlots.ActiveSlotId.Value,
		})
	end)

	return calls
end

describe("HasSaveSlots:RegisterPreSelectCallback", function()
	it("runs before the slot becomes active", function()
		local context = setup()
		local calls = recordCalls(context)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(#calls).toEqual(1)
		expect(calls[1].slotId).toEqual(slotId)
		expect(calls[1].player).toEqual(context.fakePlayer)
		expect(calls[1].activeAtCall).toBeNil()
		expect(calls[1].previousSlotId).toBeNil()
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("reports the selection being replaced when switching slots", function()
		local context = setup()

		local firstId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local secondId = await(context.hasSaveSlots:PromiseCreateSlot(2))
		await(context.hasSaveSlots:PromiseSelectSlot(firstId))

		local calls = recordCalls(context)
		await(context.hasSaveSlots:PromiseSelectSlot(secondId))

		expect(#calls).toEqual(1)
		expect(calls[1].slotId).toEqual(secondId)
		expect(calls[1].previousSlotId).toEqual(firstId)
		expect(calls[1].activeAtCall).toEqual(firstId)

		context.destroy()
	end)

	it("runs for a new slot and for an ephemeral slot alike", function()
		local context = setup()
		local calls = recordCalls(context)

		local newId = await(context.hasSaveSlots:PromiseSelectNewSaveSlot())
		local ephemeralId = await(context.hasSaveSlots:PromiseSelectEphemeralSlot({ SlotName = "Throwaway" }))

		expect(#calls).toEqual(2)
		expect(calls[1].slotId).toEqual(newId)
		expect(calls[2].slotId).toEqual(ephemeralId)

		context.destroy()
	end)

	it("does not run when the slot is already active", function()
		local context = setup()

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		local calls = recordCalls(context)
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(calls).toEqual({})

		context.destroy()
	end)

	it("stops running once removed", function()
		local context = setup()

		local ran = 0
		local remove = context.register(function()
			ran += 1
			return nil
		end)

		local firstId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(firstId))
		expect(ran).toEqual(1)

		remove()

		local secondId = await(context.hasSaveSlots:PromiseCreateSlot(2))
		await(context.hasSaveSlots:PromiseSelectSlot(secondId))
		expect(ran).toEqual(1)

		context.destroy()
	end)

	it("holds the selection until a returned promise resolves", function()
		local context = setup()

		local gate = Promise.new()
		context.register(function()
			return gate
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local selection = context.hasSaveSlots:PromiseSelectSlot(slotId)

		expect(PromiseTestUtils.awaitSettled(selection, 0.5)).toEqual(false)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		gate:Resolve()

		await(selection)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("waits on every returned promise before committing", function()
		local context = setup()

		local first = Promise.new()
		local second = Promise.new()
		context.register(function()
			return first
		end)
		context.register(function()
			return second
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local selection = context.hasSaveSlots:PromiseSelectSlot(slotId)

		first:Resolve()
		expect(PromiseTestUtils.awaitSettled(selection, 0.5)).toEqual(false)

		second:Resolve()
		await(selection)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("proceeds when a returned promise rejects", function()
		local context = setup()

		context.register(function()
			return Promise.rejected("work blew up")
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("isolates a callback that errors", function()
		local context = setup()

		context.register(function()
			error("callback blew up")
		end)
		local ranAfter = 0
		context.register(function()
			ranAfter += 1
			return nil
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)
		expect(ranAfter).toEqual(1)

		context.destroy()
	end)
end)

describe("HasSaveSlots:SetPreSelectCallbackProvider", function()
	it("runs none until a provider is set", function()
		local context = setup()

		context.hasSaveSlots:SetPreSelectCallbackProvider(nil)
		context.register(function()
			return false
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)

	it("reads the provider afresh on every selection", function()
		local context = setup()

		local firstId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local secondId = await(context.hasSaveSlots:PromiseCreateSlot(2))
		await(context.hasSaveSlots:PromiseSelectSlot(firstId))

		local ran = 0
		context.register(function()
			ran += 1
			return nil
		end)

		await(context.hasSaveSlots:PromiseSelectSlot(secondId))

		expect(ran).toEqual(1)

		context.destroy()
	end)
end)

describe("HasSaveSlots pre-select refusal", function()
	it("refuses the selection when a callback returns false", function()
		local context = setup()

		context.register(function()
			return false
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		local selection = context.hasSaveSlots:PromiseSelectSlot(slotId)

		assert(PromiseTestUtils.awaitSettled(selection, 10), "selection never settled")
		expect(selection:IsRejected()).toEqual(true)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toBeNil()

		context.destroy()
	end)

	it("refuses when a returned promise resolves false", function()
		local context = setup()

		context.register(function()
			return Promise.resolved(false)
		end)

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

		context.register(function()
			return false
		end)

		local selection = context.hasSaveSlots:PromiseSelectSlot(secondId)
		assert(PromiseTestUtils.awaitSettled(selection, 10), "selection never settled")

		expect(selection:IsRejected()).toEqual(true)
		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(firstId)

		context.destroy()
	end)

	it("still runs every callback once one has refused", function()
		local context = setup()

		context.register(function()
			return false
		end)
		local ranAfter = 0
		context.register(function()
			ranAfter += 1
			return nil
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		PromiseTestUtils.awaitSettled(context.hasSaveSlots:PromiseSelectSlot(slotId), 10)

		expect(ranAfter).toEqual(1)

		context.destroy()
	end)

	it("allows the selection when a callback errors rather than treating it as a refusal", function()
		local context = setup()

		context.register(function()
			error("callback blew up")
		end)

		local slotId = await(context.hasSaveSlots:PromiseCreateSlot(1))
		await(context.hasSaveSlots:PromiseSelectSlot(slotId))

		expect(context.hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		context.destroy()
	end)
end)
