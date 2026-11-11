--!strict
--[[
	Coverage for transferable ephemeral slots: loading one from a shared-store key, building the
	teleport slice that re-saves its live state, and re-selecting it on arrival from the trusted band
	only. Driven against separate player/shared mocked datastores plus the teleport-data test seams.

	@class HasSaveSlots.TransferableEphemeral.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local BindToCloseService = require("BindToCloseService")
local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")

local Workspace = game:GetService("Workspace")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local EPHEMERAL_KEY = SaveSlotConstants.TELEPORT_DATA_EPHEMERAL_KEY
local FAKE_USER_ID = 424242

local function setup()
	local maid = Maid.new()

	local playerMock = DataStoreMock.new()
	local sharedMock = DataStoreMock.new()

	local serviceBag = ServiceBag.new()
	local teleportDataService: any = serviceBag:GetService(require("TeleportDataService"))
	local bindToCloseService: BindToCloseService.BindToCloseService = serviceBag:GetService(BindToCloseService) :: any
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local sharedService: SaveSlotSharedDataStoreService.SaveSlotSharedDataStoreService =
		serviceBag:GetService(SaveSlotSharedDataStoreService) :: any
	local binder = serviceBag:GetService(require("HasSaveSlots"))
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(playerMock)
	sharedService:SetRobloxDataStore(sharedMock)
	serviceBag:Start()

	local fakePlayer = PlayerMock.new({ UserId = FAKE_USER_ID })
	fakePlayer.Parent = Workspace

	local hasSaveSlots = assert(binder:Bind(fakePlayer), "Failed to bind HasSaveSlots")
	hasSaveSlots.MaxSlotCount.Value = 5

	maid:GiveTask(function()
		PromiseTestUtils.awaitFulfilled(bindToCloseService:PromiseClose())
		fakePlayer:Destroy()
		serviceBag:Destroy()
	end)

	local function Destroy(_self)
		maid:DoCleaning()
	end

	local controller = {
		hasSaveSlots = hasSaveSlots,
		sharedService = sharedService,
		sharedMock = sharedMock,
		teleportDataService = teleportDataService,
		fakePlayer = fakePlayer,
		Destroy = Destroy,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

-- What a teleport re-save leaves behind, and the only thing the arrival path will load.
local function writeTransfer(context: any, key: string, export)
	return PromiseTestUtils.awaitFulfilled(
		context.sharedService:PromiseWrite(key, SaveSlotExportUtils.withKind(export, SaveSlotExportUtils.Kind.TRANSFER))
	)
end

local function activeSlotData(hasSaveSlots)
	local store = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseActiveSlotStore())
	return PromiseTestUtils.awaitFulfilled(store:LoadAll({}))
end

describe("HasSaveSlots.PromiseSelectTransferableEphemeralSlot", function()
	it("loads a transferable ephemeral slot from a shared-store key", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeTransfer(context, "code-1", { data = { Coins = 5, World_2 = { Eggs = 1 } }, slotName = "Snap" })

		local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-1"))
		expect(hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)

		local data = activeSlotData(hasSaveSlots)
		expect(data.Coins).toEqual(5)
		expect(data.World_2.Eggs).toEqual(1)

		local metadata = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseGetSlotMetadata(slotId))
		expect(metadata.IsEphemeral).toEqual(true)

		context:Destroy()
	end)

	it("rejects when the key holds no export", function()
		local context = setup()
		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("missing"))

		context:Destroy()
	end)

	it("rejects when the shared store holds a value that is not a valid export", function()
		local context = setup()
		PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseWrite("corrupt", { notAnExport = true }))
		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("corrupt"))

		context:Destroy()
	end)

	it("rejects when the shared store read fails", function()
		local context = setup()
		writeTransfer(context, "code-x", { data = { Coins = 1 } })
		context.sharedMock:FailNextRequests(1)
		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-x"))

		context:Destroy()
	end)

	it("refuses a share code, which is what keeps a leaked one from being played", function()
		local context = setup()
		-- The key reaching this path comes from the arriving client, so a code a player was handed
		-- must not load here. It is redeemed through PromiseImportEphemeralSaveSlotFromCode instead.
		PromiseTestUtils.awaitFulfilled(
			context.sharedService:PromiseWrite(
				"shared-code",
				SaveSlotExportUtils.withKind({ data = { Coins = 5 } }, SaveSlotExportUtils.Kind.CODE)
			)
		)

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("shared-code"))

		context:Destroy()
	end)

	it("refuses an entry written before kinds existed, which may be a code", function()
		local context = setup()
		PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseWrite("legacy", { data = { Coins = 5 } }))

		PromiseTestUtils.awaitRejected(context.hasSaveSlots:PromiseSelectTransferableEphemeralSlot("legacy"))

		context:Destroy()
	end)
end)

describe("HasSaveSlots.PromiseImportEphemeralSaveSlotFromCode", function()
	local function writeCode(context: any, key: string, export)
		return PromiseTestUtils.awaitFulfilled(
			context.sharedService:PromiseWrite(key, SaveSlotExportUtils.withKind(export, SaveSlotExportUtils.Kind.CODE))
		)
	end

	it("redeems a share code into a transferable ephemeral slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeCode(context, "code-redeem", { data = { Coins = 5 } })

		local slotId =
			PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode("code-redeem"))
		expect(hasSaveSlots.ActiveSlotId.Value).toEqual(slotId)
		expect(activeSlotData(hasSaveSlots).Coins).toEqual(5)

		context:Destroy()
	end)

	it("still redeems a code written before kinds existed", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseWrite("legacy-code", { data = { Coins = 9 } }))

		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode("legacy-code"))
		expect(activeSlotData(hasSaveSlots).Coins).toEqual(9)

		context:Destroy()
	end)

	it("transfers onward under a fresh key, so the code itself is never published", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeCode(context, "code-onward", { data = { Coins = 5 } })
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode("code-onward"))

		-- The client carries this key across a teleport and every client can read it, so it must not
		-- be the code -- and the slice must not write a transfer over the code's entry.
		local transferKey = assert(hasSaveSlots.ActiveTransferableEphemeralKey.Value, "No transfer key")
		expect(transferKey).never.toEqual("code-onward")

		local slice = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseBuildEphemeralTransferSlice())
		expect(slice[EPHEMERAL_KEY]).toEqual(transferKey)

		local code = PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseRead("code-onward"))
		expect(code.kind).toEqual(SaveSlotExportUtils.Kind.CODE)

		-- And the fresh key holds a transfer, which is what the arrival path will accept.
		local transfer = PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseRead(transferKey))
		expect(transfer.kind).toEqual(SaveSlotExportUtils.Kind.TRANSFER)

		context:Destroy()
	end)
end)

describe("HasSaveSlots.PromiseBuildEphemeralTransferSlice", function()
	it("re-saves the live state and carries the key", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeTransfer(context, "code-2", { data = { Coins = 5 } })
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-2"))

		-- Mutate live state after loading.
		local store = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseActiveSlotStore())
		store:Store("Coins", 99)

		local slice = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseBuildEphemeralTransferSlice())
		expect(slice[EPHEMERAL_KEY]).toEqual("code-2")

		-- The shared store now holds the mutated live state, not the state we loaded.
		local saved = PromiseTestUtils.awaitFulfilled(context.sharedService:PromiseRead("code-2"))
		expect(saved.data.Coins).toEqual(99)

		context:Destroy()
	end)

	it("resolves nil when the active slot is not a transferable ephemeral slot", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(2))
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectSlot(slotId))

		expect(PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseBuildEphemeralTransferSlice())).toBeNil()

		context:Destroy()
	end)

	it("degrades to nil (does not block the teleport) when the re-save fails", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeTransfer(context, "code-5", { data = { Coins = 5 } })
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-5"))

		-- The re-save write fails; the slice must resolve nil rather than reject.
		context.sharedMock:FailNextRequests(1)
		expect(PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseBuildEphemeralTransferSlice())).toBeNil()

		context:Destroy()
	end)
end)

describe("HasSaveSlots.PromiseLoadTransferableEphemeralSlotFromTeleport", function()
	it("re-selects the slot from a key in the trusted band", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeTransfer(context, "code-3", { data = { Coins = 7 } })

		context.teleportDataService:SetTrustedArrivedTeleportDataForTesting(
			context.fakePlayer,
			{ [EPHEMERAL_KEY] = "code-3" }
		)
		context.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(context.fakePlayer, nil) -- seal

		local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseLoadTransferableEphemeralSlotFromTeleport())
		expect(type(slotId)).toEqual("string")
		expect(activeSlotData(hasSaveSlots).Coins).toEqual(7)

		context:Destroy()
	end)

	it("re-selects the slot from a key in the client band (client-initiated teleport)", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeTransfer(context, "code-4", { data = { Coins = 7 } })

		-- Egg-hunt's menu resume is a client-initiated teleport, so the key rides the client band; the
		-- unified arrival read honors it (see PromiseLoadTransferableEphemeralSlotFromTeleport).
		context.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(
			context.fakePlayer,
			{ [EPHEMERAL_KEY] = "code-4" }
		)

		local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseLoadTransferableEphemeralSlotFromTeleport())
		expect(type(slotId)).toEqual("string")
		expect(activeSlotData(hasSaveSlots).Coins).toEqual(7)

		context:Destroy()
	end)
end)

describe("HasSaveSlots.ActiveTransferableEphemeralKey (replicated for the client teleport provider)", function()
	it("reflects the active transferable-ephemeral key and clears it on deselect", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		writeTransfer(context, "code-6", { data = { Coins = 1 } })

		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectTransferableEphemeralSlot("code-6"))
		expect(hasSaveSlots.ActiveTransferableEphemeralKey.Value).toEqual("code-6")

		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseDeselectSlot())
		expect(hasSaveSlots.ActiveTransferableEphemeralKey.Value).toBeNil()

		context:Destroy()
	end)

	it("is nil while a normal (non-transferable) slot is active", function()
		local context = setup()
		local hasSaveSlots = context.hasSaveSlots
		local slotId = PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseCreateSlot(2))
		PromiseTestUtils.awaitFulfilled(hasSaveSlots:PromiseSelectSlot(slotId))

		expect(hasSaveSlots.ActiveTransferableEphemeralKey.Value).toBeNil()

		context:Destroy()
	end)
end)
