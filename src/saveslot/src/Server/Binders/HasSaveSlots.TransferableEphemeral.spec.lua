--!strict
--[[
	Coverage for transferable ephemeral slots: loading one from a shared-store key, building the
	teleport slice that re-saves its live state, and re-selecting it on arrival from the trusted band
	only. Driven against separate player/shared mocked datastores plus the teleport-data test seams.

	@class HasSaveSlots.TransferableEphemeral.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")
local SharedSaveSlotDataStoreService = require("SharedSaveSlotDataStoreService")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local EPHEMERAL_KEY = SaveSlotConstants.TELEPORT_DATA_EPHEMERAL_KEY
local FAKE_USER_ID = 424242

local function setup()
	local playerMock = DataStoreMock.new()
	local sharedMock = DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	local teleportDataService: any = serviceBag:GetService(require("TeleportDataService"))
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local sharedService: SharedSaveSlotDataStoreService.SharedSaveSlotDataStoreService =
		serviceBag:GetService(SharedSaveSlotDataStoreService) :: any
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(playerMock)
	sharedService:SetRobloxDataStore(sharedMock)
	serviceBag:Start()

	local fakePlayer = PlayerMock.new({ UserId = FAKE_USER_ID })
	fakePlayer.Parent = Workspace

	local hasSaveSlots = assert(binder:Bind(fakePlayer), "Failed to bind HasSaveSlots")
	hasSaveSlots.MaxSlotCount.Value = 5

	local function destroy()
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end

	return {
		hasSaveSlots = hasSaveSlots,
		sharedService = sharedService,
		sharedMock = sharedMock,
		teleportDataService = teleportDataService,
		fakePlayer = fakePlayer,
		destroy = destroy,
	}
end

local function runWithContext(body)
	local context = setup()
	local ok, err = pcall(body, context)
	context.destroy()
	if not ok then
		error(err, 0)
	end
end

local function awaitValueOf(promise)
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		error("promise hung", 0)
	end
	local ok, value = promise:Yield()
	if not ok then
		error(`promise rejected: {tostring(value)}`, 0)
	end
	return value
end

local function awaitResolved(promise): boolean
	if not PromiseTestUtils.awaitSettled(promise, 10) then
		error("promise hung", 0)
	end
	return (promise:Yield())
end

local function activeSlotData(hasSaveSlots)
	local store = awaitValueOf(hasSaveSlots:PromiseActiveSlotStore())
	return awaitValueOf(store:LoadAll({}))
end

describe("HasSaveSlots.PromiseSelectTransferableEphemeralSlot", function()
	it("loads a transferable ephemeral slot from a shared-store key", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			awaitValueOf(
				context.sharedService:PromiseWrite(
					"code-1",
					{ data = { Coins = 5, World_2 = { Eggs = 1 } }, slotName = "Snap" }
				)
			)

			local slotId = awaitValueOf(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-1"))
			expect(hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

			local data = activeSlotData(hasSaveSlots)
			expect(data.Coins).toEqual(5)
			expect(data.World_2.Eggs).toEqual(1)

			local metadata = awaitValueOf(hasSaveSlots:PromiseGetSlotMetadata(slotId))
			expect(metadata.IsEphemeral).toEqual(true)
		end)
	end)

	it("rejects when the key holds no export", function()
		runWithContext(function(context)
			expect(awaitResolved(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("missing"))).toEqual(false)
		end)
	end)

	it("rejects when the shared store holds a value that is not a valid export", function()
		runWithContext(function(context)
			awaitValueOf(context.sharedService:PromiseWrite("corrupt", { notAnExport = true }))
			expect(awaitResolved(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("corrupt"))).toEqual(false)
		end)
	end)

	it("rejects when the shared store read fails", function()
		runWithContext(function(context)
			awaitValueOf(context.sharedService:PromiseWrite("code-x", { data = { Coins = 1 } }))
			context.sharedMock:FailNextRequests(1)
			expect(awaitResolved(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-x"))).toEqual(false)
		end)
	end)
end)

describe("HasSaveSlots.PromiseBuildEphemeralTransferSlice", function()
	it("re-saves the live state and carries the key", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			awaitValueOf(context.sharedService:PromiseWrite("code-2", { data = { Coins = 5 } }))
			awaitValueOf(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-2"))

			-- Mutate live state after loading.
			local store = awaitValueOf(hasSaveSlots:PromiseActiveSlotStore())
			store:Store("Coins", 99)

			local slice = awaitValueOf(hasSaveSlots:PromiseBuildEphemeralTransferSlice())
			expect(slice[EPHEMERAL_KEY]).toEqual("code-2")

			-- The shared store now holds the mutated live state, not the state we loaded.
			local saved = awaitValueOf(context.sharedService:PromiseRead("code-2"))
			expect(saved.data.Coins).toEqual(99)
		end)
	end)

	it("resolves nil when the active slot is not a transferable ephemeral slot", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			local slotId = awaitValueOf(hasSaveSlots:PromiseCreateSlot(2))
			awaitValueOf(hasSaveSlots:PromiseSelectSlot(slotId))

			expect(awaitValueOf(hasSaveSlots:PromiseBuildEphemeralTransferSlice())).toBeNil()
		end)
	end)

	it("degrades to nil (does not block the teleport) when the re-save fails", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			awaitValueOf(context.sharedService:PromiseWrite("code-5", { data = { Coins = 5 } }))
			awaitValueOf(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-5"))

			-- The re-save write fails; the slice must resolve nil rather than reject.
			context.sharedMock:FailNextRequests(1)
			expect(awaitValueOf(hasSaveSlots:PromiseBuildEphemeralTransferSlice())).toBeNil()
		end)
	end)
end)

describe("HasSaveSlots.PromiseLoadTransferableEphemeralSlotFromTeleport", function()
	it("re-selects the slot from a key in the trusted band", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			awaitValueOf(context.sharedService:PromiseWrite("code-3", { data = { Coins = 7 } }))

			context.teleportDataService:SetTrustedArrivedTeleportDataForTesting(
				context.fakePlayer,
				{ [EPHEMERAL_KEY] = "code-3" }
			)
			context.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(context.fakePlayer, nil) -- seal

			local slotId = awaitValueOf(hasSaveSlots:PromiseLoadTransferableEphemeralSlotFromTeleport())
			expect(type(slotId)).toEqual("string")
			expect(activeSlotData(hasSaveSlots).Coins).toEqual(7)
		end)
	end)

	it("ignores a key that arrived only in the untrusted client band", function()
		runWithContext(function(context)
			local hasSaveSlots = context.hasSaveSlots
			awaitValueOf(context.sharedService:PromiseWrite("code-4", { data = { Coins = 7 } }))

			-- Only the client (untrusted) band carries the key; a client must not be able to forge a transfer.
			context.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(
				context.fakePlayer,
				{ [EPHEMERAL_KEY] = "code-4" }
			)

			expect(awaitValueOf(hasSaveSlots:PromiseLoadTransferableEphemeralSlotFromTeleport())).toBeNil()
		end)
	end)
end)
