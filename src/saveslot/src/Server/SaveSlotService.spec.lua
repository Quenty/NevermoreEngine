--!strict
--[[
	Coverage for SaveSlotService's ServiceBag-driven configuration surface — the parts reachable
	without a bound Player (a headless cloud test server has none). The player-driven slot
	selection flow (which needs a real Player on the HasSaveSlots binder) is characterized
	separately at the datastore layer in SaveSlotLoadFlow.spec.

	@class SaveSlotService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotService = require("SaveSlotService")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportDataService = require("TeleportDataService")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local saveSlotService: SaveSlotService.SaveSlotService = serviceBag:GetService(SaveSlotService) :: any
	local teleportDataService: TeleportDataService.TeleportDataService =
		serviceBag:GetService(TeleportDataService) :: any
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(DataStoreMock.new())

	return {
		serviceBag = serviceBag,
		saveSlotService = saveSlotService,
		teleportDataService = teleportDataService,
		fakePlayer = function(userId: number?): Player
			return maid:Add(PlayerMock.new(if userId ~= nil then { UserId = userId } else nil))
		end,
		awaitBool = function(promise: any): boolean
			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			return value
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("SaveSlotService initialization", function()
	it("should initialize and start without a bound player", function()
		local controller = setup()

		expect(function()
			controller.serviceBag:Start()
		end).never.toThrow()
		expect(controller.saveSlotService).never.toBeNil()

		controller:destroy()
	end)
end)

describe("SaveSlotService.GetExplicitSelectionRequired", function()
	it("should default to false", function()
		local controller = setup()

		expect(controller.saveSlotService:GetExplicitSelectionRequired()).toEqual(false)

		controller:destroy()
	end)

	it("should be true after RequireExplicitSelection", function()
		local controller = setup()

		controller.saveSlotService:RequireExplicitSelection()
		expect(controller.saveSlotService:GetExplicitSelectionRequired()).toEqual(true)

		controller:destroy()
	end)
end)

describe("SaveSlotService configuration guards", function()
	it("should reject RequireExplicitSelection after Start", function()
		local controller = setup()
		controller.serviceBag:Start()

		expect(function()
			controller.saveSlotService:RequireExplicitSelection()
		end).toThrow("RequireExplicitSelection must be called before Start")

		controller:destroy()
	end)

	it("should reject SetMaxSlotCount after Start", function()
		local controller = setup()
		controller.serviceBag:Start()

		expect(function()
			controller.saveSlotService:SetMaxSlotCount(3)
		end).toThrow("SetMaxSlotCount must be called before Start")

		controller:destroy()
	end)

	it("should accept a valid SetMaxSlotCount before Start", function()
		local controller = setup()

		expect(function()
			controller.saveSlotService:SetMaxSlotCount(3)
		end).never.toThrow()

		controller:destroy()
	end)

	it("should reject a SetMaxSlotCount below 1", function()
		local controller = setup()

		expect(function()
			controller.saveSlotService:SetMaxSlotCount(0)
		end).toThrow("Bad maxSlotCount")

		controller:destroy()
	end)

	it("should accept SetUnlimitedSlots before Start", function()
		local controller = setup()

		expect(function()
			controller.saveSlotService:SetUnlimitedSlots()
		end).never.toThrow()

		controller:destroy()
	end)

	it("should reject SetUnlimitedSlots after Start", function()
		local controller = setup()
		controller.serviceBag:Start()

		expect(function()
			controller.saveSlotService:SetUnlimitedSlots()
		end).toThrow("SetMaxSlotCount must be called before Start")

		controller:destroy()
	end)

	it("should reject a non-function default summary provider", function()
		local controller = setup()

		expect(function()
			controller.saveSlotService:RegisterDefaultSummaryProvider("progress", "not a function" :: any)
		end).toThrow("Bad provider")

		controller:destroy()
	end)

	it("should reject a non-string default summary provider name", function()
		local controller = setup()

		expect(function()
			controller.saveSlotService:RegisterDefaultSummaryProvider(nil :: any, function()
				return nil :: any
			end)
		end).toThrow("Bad name")

		controller:destroy()
	end)

	it("registers a default summary provider and returns an unregister function", function()
		local controller = setup()

		local unregister
		expect(function()
			unregister = controller.saveSlotService:RegisterDefaultSummaryProvider("progress", function()
				return nil :: any
			end)
		end).never.toThrow()

		expect(type(unregister)).toEqual("function")
		expect(function()
			unregister()
		end).never.toThrow()

		controller:destroy()
	end)
end)

describe("SaveSlotService internal teleport", function()
	it("should register a provider that carries a single player's active slot id", function()
		local controller = setup()
		controller.serviceBag:Start()

		local player = controller.fakePlayer(111)
		player:SetAttribute("ActiveSlotId", "slot-xyz")

		local data = controller.teleportDataService:PromiseBuildTeleportData({ player }):Wait()
		local slice = TeleportDataEnvelopeUtils.readSlice(data, 111)
		expect(slice and slice[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toEqual("slot-xyz")

		controller:destroy()
	end)

	it("should not carry a slot id when the single player has no active slot", function()
		local controller = setup()
		controller.serviceBag:Start()

		local player = controller.fakePlayer(111)

		local data = controller.teleportDataService:PromiseBuildTeleportData({ player }):Wait()
		local slice = TeleportDataEnvelopeUtils.readSlice(data, 111)
		expect(slice and slice[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toBeNil()

		controller:destroy()
	end)

	it("should carry each player's own active slot id for a multi-player teleport", function()
		local controller = setup()
		controller.serviceBag:Start()

		local playerA = controller.fakePlayer(111)
		local playerB = controller.fakePlayer(222)
		playerA:SetAttribute("ActiveSlotId", "slot-a")
		playerB:SetAttribute("ActiveSlotId", "slot-b")

		local data = controller.teleportDataService:PromiseBuildTeleportData({ playerA, playerB }):Wait()
		local sliceA = TeleportDataEnvelopeUtils.readSlice(data, 111)
		local sliceB = TeleportDataEnvelopeUtils.readSlice(data, 222)
		expect(sliceA and sliceA[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toEqual("slot-a")
		expect(sliceB and sliceB[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toEqual("slot-b")

		controller:destroy()
	end)

	it("should report a client-initiated teleport (non-trusted band) as internal", function()
		local controller = setup()
		controller.serviceBag:Start()

		local arrived = controller.fakePlayer(111)
		controller.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(arrived, {
			[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY] = "slot-1",
		})

		expect(controller.awaitBool(controller.saveSlotService:PromiseIsInternalTeleport(arrived))).toEqual(true)

		controller:destroy()
	end)

	it("should report a server-initiated teleport (trusted band) as internal", function()
		local controller = setup()
		controller.serviceBag:Start()

		local arrived = controller.fakePlayer(111)
		controller.teleportDataService:SetTrustedArrivedTeleportDataForTesting(arrived, {
			[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY] = "slot-1",
		})
		controller.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(arrived, nil) -- no client band; seals

		expect(controller.awaitBool(controller.saveSlotService:PromiseIsInternalTeleport(arrived))).toEqual(true)

		controller:destroy()
	end)

	it("should report a fresh join (no arrived data) as not internal", function()
		local controller = setup()
		controller.serviceBag:Start()

		local fresh = controller.fakePlayer(111)
		controller.teleportDataService:SetNonTrustedArrivedTeleportDataForTesting(fresh, nil) -- fresh-join sentinel; seals

		expect(controller.awaitBool(controller.saveSlotService:PromiseIsInternalTeleport(fresh))).toEqual(false)

		controller:destroy()
	end)
end)
