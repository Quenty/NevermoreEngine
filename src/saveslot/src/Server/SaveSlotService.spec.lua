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
local PlayerDataStoreService = require("PlayerDataStoreService")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotService = require("SaveSlotService")
local ServiceBag = require("ServiceBag")
local TeleportDataEnvelopeUtils = require("TeleportDataEnvelopeUtils")
local TeleportDataService = require("TeleportDataService")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Builds a ServiceBag with SaveSlotService, and a mock-injected PlayerDataStoreService so nothing
-- touches a real datastore. Returns the bag + service; the caller decides when to Start.
local function newServiceBag()
	local serviceBag = ServiceBag.new()
	local playerDataStoreService = (
		serviceBag:GetService(PlayerDataStoreService) :: any
	) :: PlayerDataStoreService.PlayerDataStoreService
	local saveSlotService = (serviceBag:GetService(SaveSlotService) :: any) :: SaveSlotService.SaveSlotService
	local teleportDataService = (
		serviceBag:GetService(TeleportDataService) :: any
	) :: TeleportDataService.TeleportDataService
	serviceBag:Init()
	playerDataStoreService:SetRobloxDataStore(DataStoreMock.new())

	-- Fake players (Folders) have no real UserId; key envelope slices off a "UserId" attribute.
	local anyTeleportDataService = teleportDataService :: any
	anyTeleportDataService._getUserId = function(_self, player: Instance): any
		return player:GetAttribute("UserId")
	end

	return serviceBag, saveSlotService, teleportDataService
end

-- A Folder is an Instance, so it satisfies the player guards and can carry the ActiveSlotId and
-- UserId attributes the provider/envelope read, standing in for a Player without a real join.
local function fakePlayer(userId: number?): Player
	local player = Instance.new("Folder")
	if userId ~= nil then
		player:SetAttribute("UserId", userId)
	end
	return (player :: any) :: Player
end

describe("SaveSlotService initialization", function()
	it("should initialize and start without a bound player", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			serviceBag:Start()
		end).never.toThrow()
		expect(saveSlotService).never.toBeNil()

		serviceBag:Destroy()
	end)
end)

describe("SaveSlotService.GetExplicitSelectionRequired", function()
	it("should default to false", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(saveSlotService:GetExplicitSelectionRequired()).toEqual(false)

		serviceBag:Destroy()
	end)

	it("should be true after RequireExplicitSelection", function()
		local serviceBag, saveSlotService = newServiceBag()

		saveSlotService:RequireExplicitSelection()
		expect(saveSlotService:GetExplicitSelectionRequired()).toEqual(true)

		serviceBag:Destroy()
	end)
end)

describe("SaveSlotService configuration guards", function()
	it("should reject RequireExplicitSelection after Start", function()
		local serviceBag, saveSlotService = newServiceBag()
		serviceBag:Start()

		expect(function()
			saveSlotService:RequireExplicitSelection()
		end).toThrow("RequireExplicitSelection must be called before Start")

		serviceBag:Destroy()
	end)

	it("should reject SetMaxSlotCount after Start", function()
		local serviceBag, saveSlotService = newServiceBag()
		serviceBag:Start()

		expect(function()
			saveSlotService:SetMaxSlotCount(3)
		end).toThrow("SetMaxSlotCount must be called before Start")

		serviceBag:Destroy()
	end)

	it("should accept a valid SetMaxSlotCount before Start", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetMaxSlotCount(3)
		end).never.toThrow()

		serviceBag:Destroy()
	end)

	it("should reject a SetMaxSlotCount below 1", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetMaxSlotCount(0)
		end).toThrow("Bad maxSlotCount")

		serviceBag:Destroy()
	end)

	it("should accept SetUnlimitedSlots before Start", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetUnlimitedSlots()
		end).never.toThrow()

		serviceBag:Destroy()
	end)

	it("should reject SetUnlimitedSlots after Start", function()
		local serviceBag, saveSlotService = newServiceBag()
		serviceBag:Start()

		-- Delegates to SetMaxSlotCount, so it surfaces the same before-Start guard
		expect(function()
			saveSlotService:SetUnlimitedSlots()
		end).toThrow("SetMaxSlotCount must be called before Start")

		serviceBag:Destroy()
	end)

	it("should reject a non-function summary provider", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetDefaultSummaryProvider("not a function" :: any)
		end).toThrow("Bad provider")

		serviceBag:Destroy()
	end)

	it("should accept a function summary provider", function()
		local serviceBag, saveSlotService = newServiceBag()

		expect(function()
			saveSlotService:SetDefaultSummaryProvider((function()
				return nil
			end) :: any)
		end).never.toThrow()

		serviceBag:Destroy()
	end)
end)

describe("SaveSlotService internal teleport", function()
	it("should register a provider that carries a single player's active slot id", function()
		local serviceBag, _saveSlotService, teleportDataService = newServiceBag()
		serviceBag:Start()

		local player = fakePlayer(111)
		player:SetAttribute("ActiveSlotId", "slot-xyz")

		local data = teleportDataService:BuildTeleportData({ player })
		local slice = TeleportDataEnvelopeUtils.readSlice(data, 111)
		expect(slice and slice[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toEqual("slot-xyz")

		player:Destroy()
		serviceBag:Destroy()
	end)

	it("should not carry a slot id when the single player has no active slot", function()
		local serviceBag, _saveSlotService, teleportDataService = newServiceBag()
		serviceBag:Start()

		local player = fakePlayer(111)

		local data = teleportDataService:BuildTeleportData({ player })
		local slice = TeleportDataEnvelopeUtils.readSlice(data, 111)
		expect(slice and slice[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toBeNil()

		player:Destroy()
		serviceBag:Destroy()
	end)

	it("should carry each player's own active slot id for a multi-player teleport", function()
		local serviceBag, _saveSlotService, teleportDataService = newServiceBag()
		serviceBag:Start()

		local playerA = fakePlayer(111)
		local playerB = fakePlayer(222)
		playerA:SetAttribute("ActiveSlotId", "slot-a")
		playerB:SetAttribute("ActiveSlotId", "slot-b")

		local data = teleportDataService:BuildTeleportData({ playerA, playerB })
		local sliceA = TeleportDataEnvelopeUtils.readSlice(data, 111)
		local sliceB = TeleportDataEnvelopeUtils.readSlice(data, 222)
		expect(sliceA and sliceA[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toEqual("slot-a")
		expect(sliceB and sliceB[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY]).toEqual("slot-b")

		playerA:Destroy()
		playerB:Destroy()
		serviceBag:Destroy()
	end)

	it("should report IsInternalTeleport from the arrived teleport data", function()
		local serviceBag, saveSlotService, teleportDataService = newServiceBag()
		serviceBag:Start()

		local arrived = fakePlayer()
		teleportDataService:SetArrivedTeleportDataForTesting(arrived, {
			[SaveSlotConstants.TELEPORT_DATA_SLOT_KEY] = "slot-1",
		})
		expect(saveSlotService:IsInternalTeleport(arrived)).toEqual(true)

		local fresh = fakePlayer()
		teleportDataService:SetArrivedTeleportDataForTesting(fresh, {})
		expect(saveSlotService:IsInternalTeleport(fresh)).toEqual(false)

		arrived:Destroy()
		fresh:Destroy()
		serviceBag:Destroy()
	end)
end)
