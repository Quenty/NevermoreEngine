--!strict
--[[
	@class HasSaveSlotsClient.spec
]]
local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local HasSaveSlotsClient = require("HasSaveSlotsClient")
local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")
local TeleportDataServiceClient = require("TeleportDataServiceClient")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_USER_ID = 424242

local activeMaid: Maid.Maid? = nil

afterEach(function()
	if activeMaid then
		local maid = activeMaid
		activeMaid = nil
		maid:DoCleaning()
	end
	PlayerMock.setMockedLocalPlayer(nil)
end)

local function setup(): (Maid.Maid, any, any)
	local maid = Maid.new()
	activeMaid = maid

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
		PlayerMock.setMockedLocalPlayer(playerMock)
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

		local observed: string? = nil
		maid:GiveTask(dataService:ObserveActiveSlotId(playerMock):Subscribe(function(slotId: string?)
			observed = slotId
		end))

		PromiseTestUtils.awaitValue(function()
			return observed == "slot-a"
		end, 5)
		expect(observed).toEqual("slot-a")

		playerMock:SetAttribute("ActiveSlotId", "slot-b")
		PromiseTestUtils.awaitValue(function()
			return observed == "slot-b"
		end, 5)
		expect(observed).toEqual("slot-b")
	end)
end)
