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

local CmdrReplyUtils = require("CmdrReplyUtils")
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
local OTHER_USER_ID = 5151

-- Short enough that the progress test does not have to sit through the real threshold.
local SLOW_REPLY_SECONDS = 0.05

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService =
		serviceBag:GetService(PlayerDataStoreService) :: any
	local saveSlotService: SaveSlotService.SaveSlotService = serviceBag:GetService(SaveSlotService) :: any
	-- The store behind share codes, mocked separately from the player store the slots themselves live in.
	local sharedService: any = serviceBag:GetService(require("SaveSlotSharedDataStoreService"))
	serviceBag:Init()

	local mock = DataStoreMock.new()
	playerDataStoreService:SetRobloxDataStore(mock)
	sharedService:SetRobloxDataStore(DataStoreMock.new())
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

	-- Typed loosely: the fields are filled in by hand below rather than by Init, so the table is not a
	-- SaveSlotCmdrService until the last of them lands.
	local service: any = setmetatable({}, { __index = SaveSlotCmdrService })
	service._maid = Maid.new()
	service._serviceBag = serviceBag
	service._cmdrService = cmdrService
	service._playerDataStoreService = playerDataStoreService
	service._saveSlotDataService = serviceBag:GetService(require("SaveSlotDataService"))
	service._hasSaveSlotsBinder = serviceBag:GetService(require("HasSaveSlots"))
	-- Shadows the module-instance lookup, which resolves SaveSlotService through the script tree to
	-- dodge a require cycle. Handing it over directly keeps that indirection out of the test.
	service._getSaveSlotService = function()
		return saveSlotService
	end
	service:SetReplyConfig(CmdrReplyUtils.createConfig({ slowReplySeconds = SLOW_REPLY_SECONDS }))
	service:Start()

	maid:GiveTask(function()
		service._maid:Destroy()
	end)

	local replies: { string } = {}
	local context = {
		Reply = function(_self, text: string)
			table.insert(replies, text)
		end,
	}

	return {
		mock = mock,
		replies = replies,
		run = function(commandName: string, ...)
			return registered[commandName](context, ...)
		end,
		seed = function(raw, userId: number?)
			mock:SetRaw(tostring(userId or ABSENT_USER_ID), raw)
		end,
		readRaw = function(userId: number?)
			return mock:GetRaw(tostring(userId or ABSENT_USER_ID))
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

		local output = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(output, "Alpha", 1, true) ~= nil).toEqual(true)
		expect(string.find(output, tostring(ABSENT_USER_ID), 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("lists a slot's summary and playtime, which is what the listing is read for", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = {
						SlotIndex = 1,
						SlotName = "Alpha",
						TimePlayed = 5000,
						PlayCount = 4,
						Summary = { progress = { chapter = 3 } },
					},
				},
			},
		})

		local output = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(output, "progress: chapter = 3", 1, true) ~= nil).toEqual(true)
		expect(string.find(output, "played 1h 23m, 4 session(s)", 1, true) ~= nil).toEqual(true)
		-- The bug this replaced: a structured summary printed as "table: 0x...".
		expect(string.find(output, "table: 0x", 1, true)).toBeNil()

		controller.destroy()
	end)

	it("creates a slot that lands in their datastore", function()
		local controller = setup()

		local output = controller.run("saveslot-create", { ABSENT_USER_ID }, { 2 })
		expect(string.find(output, "created slot(s) 2", 1, true) ~= nil).toEqual(true)

		-- The session is released when the command finishes, which is what flushes the write.
		local raw = controller.readRaw()
		expect(raw).never.toBeNil()
		expect(raw.SaveSlots).never.toBeNil()

		-- And a second command sees it, which it only can if the first one really persisted.
		local listed = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(listed, "(2)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("deletes a stored slot", function()
		local controller = setup()

		controller.run("saveslot-create", { ABSENT_USER_ID }, { 1, 2 })

		local output = controller.run("saveslot-delete", { ABSENT_USER_ID }, { 1 })
		expect(string.find(output, "deleted slot 1", 1, true) ~= nil).toEqual(true)

		local listed = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(listed, "(1)", 1, true)).toBeNil()
		expect(string.find(listed, "(2)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("copies a slot into the lowest free index when no destination is given", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 1, SlotName = "Alpha" },
				},
			},
		})

		local output = controller.run("saveslot-copy", ABSENT_USER_ID, 1, { ABSENT_USER_ID })
		expect(string.find(output, "slot 1 →", 1, true) ~= nil).toEqual(true)

		-- Inside one roster the copy is suffixed, so it does not sit beside the original under its name.
		local listed = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(listed, "Alpha (Copy)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("copies one player's slot onto another player's, in their own datastore", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 2, SlotName = "Alpha" },
				},
				slots = {
					["slot-a"] = { coins = 100 },
				},
			},
		})

		local output = controller.run("saveslot-copy", ABSENT_USER_ID, 2, { OTHER_USER_ID })
		expect(string.find(output, `Copied {ABSENT_USER_ID} slot 2 → {OTHER_USER_ID} slot 2`, 1, true) ~= nil).toEqual(
			true
		)

		-- Landed in the other player's own key, keeping the source's name -- only a copy inside one
		-- roster is suffixed.
		expect(controller.readRaw(OTHER_USER_ID)).never.toBeNil()
		local listed = controller.run("saveslot-list", { OTHER_USER_ID })
		expect(string.find(listed, '"Alpha" (2)', 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("copies onto the named destination, overwriting the slot already there", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 2, SlotName = "Alpha" },
					["slot-b"] = { SlotIndex = 3, SlotName = "Beta" },
				},
			},
		})

		local output = controller.run("saveslot-copy", ABSENT_USER_ID, 2, { ABSENT_USER_ID }, 3)
		expect(string.find(output, "overwriting what was there", 1, true) ~= nil).toEqual(true)

		-- Beta is gone, and slot 3 is now the copy of Alpha rather than a fourth slot.
		local listed = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(listed, "Beta", 1, true)).toBeNil()
		expect(string.find(listed, "(4)", 1, true)).toBeNil()
		expect(string.find(listed, 'Alpha (Copy)" (3)', 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("refuses a copy whose source and destination are the same slot", function()
		local controller = setup()

		controller.run("saveslot-create", { ABSENT_USER_ID }, { 2 })

		local output = controller.run("saveslot-copy", ABSENT_USER_ID, 2, { ABSENT_USER_ID }, 2)
		expect(string.find(output, "both the source and the destination", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("refuses the main slot as a destination, whose store is the player's root data", function()
		local controller = setup()

		controller.run("saveslot-create", { ABSENT_USER_ID }, { 1, 2 })

		local output = controller.run("saveslot-copy", ABSENT_USER_ID, 2, { ABSENT_USER_ID }, 1)
		expect(string.find(output, "main slot (1) cannot be copied onto", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("round-trips a slot through export and import, the console's own share-code loop", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 2, SlotName = "Alpha" },
				},
				slots = {
					["slot-a"] = { coins = 100 },
				},
			},
		})

		local exported = controller.run("saveslot-export", { ABSENT_USER_ID }, { 2 })
		local code = string.match(exported, "→ (%S+)")
		expect(code).never.toBeNil()

		-- Imported onto a second player, which is what a hand-off across the console looks like.
		local output = controller.run("saveslot-import", OTHER_USER_ID, code)
		expect(string.find(output, "Imported save slot from code", 1, true) ~= nil).toEqual(true)

		local listed = controller.run("saveslot-list", { OTHER_USER_ID })
		expect(string.find(listed, '"Alpha"', 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("round-trips a slot through read-json and write-json", function()
		local controller = setup()

		controller.seed({
			SaveSlots = {
				slotMetadata = {
					["slot-a"] = { SlotIndex = 2, SlotName = "Alpha" },
				},
				slots = {
					["slot-a"] = { coins = 100 },
				},
			},
		})

		local read = controller.run("saveslot-read-json", { ABSENT_USER_ID }, { 2 })
		-- The command prefixes a "-- player slot N" comment line; the JSON is the rest.
		local json = string.match(read, "\n(.+)$")
		expect(json).never.toBeNil()

		local output = controller.run("saveslot-write-json", { ABSENT_USER_ID }, json)
		expect(string.find(output, "wrote JSON → slot 3", 1, true) ~= nil).toEqual(true)

		local listed = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(listed, "(3)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("reports malformed write-json input without touching anyone's data", function()
		local controller = setup()

		local output = controller.run("saveslot-write-json", { ABSENT_USER_ID }, "not json")
		expect(string.find(output, "could not decode JSON", 1, true) ~= nil).toEqual(true)
		expect(controller.readRaw()).toBeNil()

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

		local output = controller.run("saveslot-get-active", { ABSENT_USER_ID })
		expect(string.find(output, "would resume on slot 3", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("releases the session, so back-to-back commands both work", function()
		local controller = setup()

		controller.run("saveslot-create", { ABSENT_USER_ID }, { 1 })

		-- A leaked session would leave the second command waiting on a lock this server still holds.
		local promise = Promise.new(function(resolve)
			resolve(controller.run("saveslot-create", { ABSENT_USER_ID }, { 2 }))
		end)
		expect(PromiseTestUtils.awaitSettled(promise, 10)).toEqual(true)

		local listed = controller.run("saveslot-list", { ABSENT_USER_ID })
		expect(string.find(listed, "(1)", 1, true) ~= nil).toEqual(true)
		expect(string.find(listed, "(2)", 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)

	it("reports an empty target list rather than doing nothing quietly", function()
		local controller = setup()

		expect(controller.run("saveslot-list", {})).toEqual("No players to act on.")

		controller.destroy()
	end)

	it("reports a target that is taking a while", function()
		local controller = setup()

		controller.mock:SetYieldTime(SLOW_REPLY_SECONDS * 2)

		controller.run("saveslot-list", { ABSENT_USER_ID })

		expect(#controller.replies).toEqual(1)
		expect(string.find(controller.replies[1], tostring(ABSENT_USER_ID), 1, true) ~= nil).toEqual(true)

		controller.destroy()
	end)
end)
