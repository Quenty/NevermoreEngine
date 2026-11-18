--!strict
--[[
	@class HasSaveSlotsClient.spec
]]
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local HasSaveSlotsClient = require("HasSaveSlotsClient")
local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")
local TeleportDataServiceClient = require("TeleportDataServiceClient")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local function setup(): (Maid.Maid, any, any)
	local maid = Maid.new()

	maid:GiveTask(JestUtils.afterThis(maid))

	local serviceBag = maid:Add(ServiceBag.new())
	local tieRealmService = serviceBag:GetService(TieRealmService) :: any
	tieRealmService:SetTieRealm(TieRealms.CLIENT)
	local binder = serviceBag:GetService(HasSaveSlotsClient) :: any
	local dataService = serviceBag:GetService(SaveSlotDataService) :: any
	serviceBag:GetService(TeleportDataServiceClient)
	serviceBag:Init()
	serviceBag:Start()

	return maid, binder, dataService
end

local function newPlayerMock(maid: Maid.Maid, isLocalPlayer: boolean): Player
	local playerMock = PlayerMock.new({ UserId = FAKE_USER_ID })
	playerMock.Parent = Workspace
	maid:GiveTask(function()
		playerMock:Destroy()
	end)
	if isLocalPlayer then
		maid:GiveTask(PlayerMock.setMockedLocalPlayer(playerMock))
	end
	return playerMock
end

describe("HasSaveSlotsClient local-player gate", function()
	it("creates no client implementation for a mock that is not the local player", function()
		local maid, binder = setup()
		local playerMock = newPlayerMock(maid, false)

		binder:Bind(playerMock)

		expect(HasSaveSlotsInterface:Find(playerMock, TieRealms.CLIENT)).toBeNil()
	end)

	it("creates the client implementation for the local-player mock", function()
		local maid, binder = setup()
		local playerMock = newPlayerMock(maid, true)

		binder:Bind(playerMock)

		expect(HasSaveSlotsInterface:Find(playerMock, TieRealms.CLIENT)).never.toBeNil()
	end)
end)

describe("HasSaveSlotsClient active-slot observation", function()
	it("emits the active slot id client-side, and updates as it changes", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		playerMock:SetAttribute("ActiveSlotId", "slot-a")

		local observedValues = maid:Add(ObservableSpy.new(dataService:ObserveActiveSlotId(playerMock)))

		expect(observedValues:GetLastValue()).toEqual("slot-a")

		playerMock:SetAttribute("ActiveSlotId", "slot-b")
		expect(observedValues:GetLastValue()).toEqual("slot-b")
	end)
end)

local REAL_ID = "real-slot"
local EPHEMERAL_ID = "ephemeral-slot"

-- Unparented, so each test decides when the slot "replicates".
local function newSlot(slotId: string, slotIndex: number, slotName: string, isEphemeral: boolean?): Folder
	local slot = Instance.new("Folder")
	slot.Name = slotId
	slot:SetAttribute("SlotIndex", slotIndex)
	slot:SetAttribute("SlotName", slotName)
	if isEphemeral then
		slot:SetAttribute("IsEphemeral", true)
	end
	return slot
end

local function newSlotContainer(maid: Maid.Maid): Folder
	local container = maid:Add(Instance.new("Folder"))
	container.Name = "SaveSlots"
	return container
end

local function latestMatches(record: ObservableSpy.ObservableSpy<any>, predicate: (any) -> boolean): boolean
	return predicate(record:GetLastValue())
end

local function listedIds(slotList: { any }?): { [string]: boolean }
	local ids = {}
	for _, metadata in (slotList or {}) :: { any } do
		ids[metadata.SlotId] = true
	end
	return ids
end

describe("SaveSlotDataService active-slot metadata on the client", function()
	it("emits nil immediately when nothing has replicated yet", function()
		local maid, _, dataService = setup()
		local playerMock = newPlayerMock(maid, true)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveActiveSlotMetadata(playerMock)))

		expect(#record).toEqual(1)
		expect(record:GetLastValue()).toBeNil()
	end)

	it("resolves the active ephemeral slot when its folder arrives after the active-slot id", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveActiveSlotMetadata(playerMock)))
		expect(record:GetLastValue()).toBeNil()

		local container = newSlotContainer(maid)
		newSlot(EPHEMERAL_ID, 0, "Lobby run", true).Parent = container
		container.Parent = playerMock

		expect(latestMatches(record, function(metadata)
			return metadata ~= nil and metadata.SlotName == "Lobby run"
		end)).toEqual(true)
		expect(record:GetLastValue().SlotId).toEqual(EPHEMERAL_ID)
		expect(record:GetLastValue().IsEphemeral).toEqual(true)
	end)

	it("resolves the active ephemeral slot when the active-slot id arrives after its folder", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		newSlot(EPHEMERAL_ID, 0, "Lobby run", true).Parent = container
		container.Parent = playerMock

		local record = maid:Add(ObservableSpy.new(dataService:ObserveActiveSlotMetadata(playerMock)))
		expect(record:GetLastValue()).toBeNil()

		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		expect(latestMatches(record, function(metadata)
			return metadata ~= nil and metadata.SlotId == EPHEMERAL_ID
		end)).toEqual(true)
	end)

	it("emits nil again when the ephemeral slot's folder goes away under a still-set active-slot id", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		local ephemeralSlot = newSlot(EPHEMERAL_ID, 0, "Lobby run", true)
		ephemeralSlot.Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveActiveSlotMetadata(playerMock)))
		expect(latestMatches(record, function(metadata)
			return metadata ~= nil
		end)).toEqual(true)

		-- A retire replicates as the folder disappearing; the id can still name it for a frame.
		ephemeralSlot:Destroy()

		expect(latestMatches(record, function(metadata)
			return metadata == nil
		end)).toEqual(true)
	end)

	it("follows a switch from the ephemeral slot to a real one", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		local ephemeralSlot = newSlot(EPHEMERAL_ID, 0, "Lobby run", true)
		ephemeralSlot.Parent = container
		newSlot(REAL_ID, 1, "Slot 1").Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveActiveSlotMetadata(playerMock)))
		expect(latestMatches(record, function(metadata)
			return metadata ~= nil and metadata.SlotId == EPHEMERAL_ID
		end)).toEqual(true)

		playerMock:SetAttribute("ActiveSlotId", REAL_ID)
		ephemeralSlot:Destroy()

		expect(latestMatches(record, function(metadata)
			return metadata ~= nil and metadata.SlotId == REAL_ID
		end)).toEqual(true)
		expect(record:GetLastValue().IsEphemeral).toBeNil()
	end)

	it("reads the active ephemeral slot synchronously too", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		newSlot(EPHEMERAL_ID, 0, "Lobby run", true).Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		expect(dataService:GetActiveSlotMetadata(playerMock)).never.toBeNil()

		local metadata = dataService:GetActiveSlotMetadata(playerMock)
		expect(metadata.SlotId).toEqual(EPHEMERAL_ID)
		expect(metadata.IsEphemeral).toEqual(true)
		expect(dataService:IsActiveSlotEphemeral(playerMock)).toEqual(true)
	end)
end)

describe("SaveSlotDataService ephemeral-state observation on the client", function()
	it("stays false until the IsEphemeral attribute lands, then flips to true", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		local slot = newSlot(EPHEMERAL_ID, 0, "Lobby run")
		slot.Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveIsActiveSlotEphemeral(playerMock)))
		expect(record:GetLastValue()).toEqual(false)

		slot:SetAttribute("IsEphemeral", true)

		expect(latestMatches(record, function(isEphemeral)
			return isEphemeral == true
		end)).toEqual(true)
		expect(record.Values).toEqual({ false, true })
	end)

	it("does not re-emit when unrelated metadata on the active slot changes", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		local slot = newSlot(EPHEMERAL_ID, 0, "Lobby run", true)
		slot.Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveIsActiveSlotEphemeral(playerMock)))
		expect(latestMatches(record, function(isEphemeral)
			return isEphemeral == true
		end)).toEqual(true)

		local countAfterResolve = #record
		slot:SetAttribute("SlotName", "Lobby run 2")
		slot:SetAttribute("TimePlayed", 90)

		expect(#record).toEqual(countAfterResolve)
		expect(record:GetLastValue()).toEqual(true)
	end)

	it("returns to false when the ephemeral slot is retired", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		local slot = newSlot(EPHEMERAL_ID, 0, "Lobby run", true)
		slot.Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", EPHEMERAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveIsActiveSlotEphemeral(playerMock)))
		expect(latestMatches(record, function(isEphemeral)
			return isEphemeral == true
		end)).toEqual(true)

		playerMock:SetAttribute("ActiveSlotId", nil)
		slot:Destroy()

		expect(latestMatches(record, function(isEphemeral)
			return isEphemeral == false
		end)).toEqual(true)
		expect(dataService:IsActiveSlotEphemeral(playerMock)).toEqual(false)
	end)

	it("reports false for a real active slot", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		newSlot(REAL_ID, 1, "Slot 1").Parent = container
		container.Parent = playerMock
		playerMock:SetAttribute("ActiveSlotId", REAL_ID)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveIsActiveSlotEphemeral(playerMock)))

		expect(dataService:GetActiveSlotMetadata(playerMock)).never.toBeNil()
		expect(record.Values).toEqual({ false })
		expect(dataService:IsActiveSlotEphemeral(playerMock)).toEqual(false)
	end)
end)

describe("SaveSlotDataService slot list on the client", function()
	it("emits nil rather than staying silent when the slot container has not replicated", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local record = maid:Add(ObservableSpy.new(dataService:ObserveSlotList(playerMock)))

		expect(#record).toEqual(1)
		expect(record:GetLastValue()).toBeNil()
	end)

	it("lists the real slot but not the ephemeral one", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		newSlot(REAL_ID, 1, "Slot 1").Parent = container
		newSlot(EPHEMERAL_ID, 0, "Lobby run", true).Parent = container
		container.Parent = playerMock

		local synchronous = listedIds(dataService:GetSlotList(playerMock))
		expect(synchronous[REAL_ID]).toEqual(true)
		expect(synchronous[EPHEMERAL_ID]).toBeNil()

		local record = maid:Add(ObservableSpy.new(dataService:ObserveSlotList(playerMock)))
		expect(latestMatches(record, function(slotList)
			return listedIds(slotList)[REAL_ID] == true
		end)).toEqual(true)
		expect(listedIds(record:GetLastValue())[EPHEMERAL_ID]).toBeNil()
	end)

	it("replaces rather than appends a slot's entry when its metadata changes", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		local slot = newSlot(REAL_ID, 1, "Slot 1")
		slot.Parent = container
		container.Parent = playerMock

		local record = maid:Add(ObservableSpy.new(dataService:ObserveSlotList(playerMock)))
		expect(latestMatches(record, function(slotList)
			return listedIds(slotList)[REAL_ID] == true
		end)).toEqual(true)

		slot:SetAttribute("SlotName", "Renamed")

		expect(latestMatches(record, function(slotList)
			return slotList ~= nil and slotList[1] ~= nil and slotList[1].SlotName == "Renamed"
		end)).toEqual(true)
		expect(#record:GetLastValue()).toEqual(1)
	end)

	it("drops the slot from the list when its IsEphemeral attribute lands after the folder", function()
		local maid, binder, dataService = setup()
		local playerMock = newPlayerMock(maid, true)
		binder:Bind(playerMock)

		local container = newSlotContainer(maid)
		newSlot(REAL_ID, 1, "Slot 1").Parent = container
		local slot = newSlot(EPHEMERAL_ID, 0, "Lobby run")
		slot.Parent = container
		container.Parent = playerMock

		local record = maid:Add(ObservableSpy.new(dataService:ObserveSlotList(playerMock)))
		expect(latestMatches(record, function(slotList)
			return listedIds(slotList)[EPHEMERAL_ID] == true
		end)).toEqual(true)

		slot:SetAttribute("IsEphemeral", true)

		expect(latestMatches(record, function(slotList)
			return listedIds(slotList)[EPHEMERAL_ID] == nil
		end)).toEqual(true)
		expect(listedIds(record:GetLastValue())[REAL_ID]).toEqual(true)
		expect(listedIds(dataService:GetSlotList(playerMock))[EPHEMERAL_ID]).toBeNil()
	end)
end)
