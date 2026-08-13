--!strict
--[[
	Drives the command bodies directly against a player who is not in this server. The service is built
	by hand rather than through a ServiceBag so the real CmdrService (and the Cmdr instance tree behind
	it) stays out of the test place -- what is worth checking here is that a command reaches an absent
	player's stored data at all, and hands their session back afterwards.

	Command bodies take the userId list Cmdr's `playerIds` type parses, so these pass one directly.
	Slot arguments are passed as resolved indices, which is what the `slotIndices` type produces.

	@class SaveSlotCmdrService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreMock = require("DataStoreMock")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local SaveSlotCmdrService = require("SaveSlotCmdrService")
local SaveSlotService = require("SaveSlotService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local ABSENT_USER_ID = 5150

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local saveSlotService: SaveSlotService.SaveSlotService = serviceBag:GetService(SaveSlotService) :: any
	serviceBag:Init()

	local mock = DataStoreMock.new()
	playerDataStoreService:SetRobloxDataStore(mock)
	saveSlotService:SetMaxSlotCount(5)
	serviceBag:Start()

	local registered = {}
	local cmdr = {
		Registry = {
			RegisterType = function() end,
		},
		Util = {
			MakeFuzzyFinder = function()
				return function()
					return {}
				end
			end,
			MakeListableType = function(definition)
				return definition
			end,
		},
	}
	local cmdrService = {
		RegisterCommand = function(_self, definition, execute)
			registered[definition.Name] = execute
		end,
		PromiseCmdr = function()
			return Promise.resolved(cmdr)
		end,
	}

	local service = setmetatable({}, { __index = SaveSlotCmdrService })
	service._maid = Maid.new()
	service._serviceBag = serviceBag
	service._cmdrService = cmdrService
	service._saveSlotDataService = serviceBag:GetService(require("SaveSlotDataService"))
	service._hasSaveSlotsBinder = serviceBag:GetService(require("HasSaveSlots"))
	-- Shadows the module-instance lookup, which resolves SaveSlotService through the script tree to
	-- dodge a require cycle. Handing it over directly keeps that indirection out of the test.
	service._getSaveSlotService = function()
		return saveSlotService
	end
	service:Start()

	maid:GiveTask(function()
		service._maid:Destroy()
	end)

	return {
		mock = mock,
		run = function(commandName: string, ...)
			return registered[commandName](nil, ...)
		end,
		seed = function(raw)
			mock:SetRaw(tostring(ABSENT_USER_ID), raw)
		end,
		readRaw = function()
			return mock:GetRaw(tostring(ABSENT_USER_ID))
		end,
		destroy = function()
			DataStoreTestUtils.awaitServiceShutdown(playerDataStoreService)
			maid:DoCleaning()
		end,
	}
end

describe("SaveSlotCmdrService against an absent player", function()
	it("lists the stored slots", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 1, SlotName = "Alpha" },
				},
			},
		})

		local output = controller.run("list-save-slots", { ABSENT_USER_ID })
		expect(string.find(output, "Alpha", 1, true) ~= nil).toEqual(true)
		expect(string.find(output, tostring(ABSENT_USER_ID), 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("creates a slot that lands in their datastore", function()
		local controller = setup()

		local output = controller.run("create-save-slot", { ABSENT_USER_ID }, { 2 })
		expect(string.find(output, "created slot(s) 2", 1, true) ~= nil).toEqual(true)

		-- The session is released when the command finishes, which is what flushes the write.
		local raw = controller.readRaw()
		expect(raw).never.toBeNil()
		expect(raw.SaveSlots).never.toBeNil()

		-- And a second command sees it, which it only can if the first one really persisted.
		local listed = controller.run("list-save-slots", { ABSENT_USER_ID })
		expect(string.find(listed, "(2)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("deletes a stored slot", function()
		local controller = setup()

		controller.run("create-save-slot", { ABSENT_USER_ID }, { 1, 2 })

		local output = controller.run("delete-save-slot", { ABSENT_USER_ID }, { 1 })
		expect(string.find(output, "deleted slot 1", 1, true) ~= nil).toEqual(true)

		local listed = controller.run("list-save-slots", { ABSENT_USER_ID })
		expect(string.find(listed, "(1)", 1, true)).toBeNil()
		expect(string.find(listed, "(2)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("reports the slot they would resume on, since nothing is selected offline", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 3, SlotName = "Gamma" },
				},
				activeSlotId = "slot-a",
			},
		})

		local output = controller.run("get-active-save-slot", { ABSENT_USER_ID })
		expect(string.find(output, "would resume on slot 3", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("releases the session, so back-to-back commands both work", function()
		local controller = setup()

		controller.run("create-save-slot", { ABSENT_USER_ID }, { 1 })

		-- A leaked session would leave the second command waiting on a lock this server still holds.
		local promise = Promise.new(function(resolve)
			resolve(controller.run("create-save-slot", { ABSENT_USER_ID }, { 2 }))
		end)
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toEqual(true)

		local listed = controller.run("list-save-slots", { ABSENT_USER_ID })
		expect(string.find(listed, "(1)", 1, true) ~= nil).toEqual(true)
		expect(string.find(listed, "(2)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("reports an empty target list rather than doing nothing quietly", function()
		local controller = setup()

		expect(controller.run("list-save-slots", {})).toEqual("No players to act on.")

		controller.destroy()
	end)
end)
