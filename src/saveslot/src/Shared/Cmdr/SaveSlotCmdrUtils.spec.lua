--!strict
--[[
	@class SaveSlotCmdrUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SaveSlotCmdrUtils = require("SaveSlotCmdrUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FAKE_PLAYER = newproxy(false)

local function newFakeDataService(state: any)
	-- Mirrors the real service: an ephemeral slot is excluded from the slot list but still resolvable as
	-- metadata, which is exactly the split the type has to bridge.
	return {
		GetSlotList = function(_self, _player)
			return state.slots
		end,
		GetLastActiveSlotId = function(_self, _player)
			return state.lastActiveSlotId
		end,
		IsActiveSlotEphemeral = function(_self, _player)
			return state.ephemeralSlot ~= nil
		end,
		GetSlotMetadata = function(_self, _player, slotId)
			if state.ephemeralSlot and state.ephemeralSlot.SlotId == slotId then
				return state.ephemeralSlot
			end
			for _, slot in state.slots do
				if slot.SlotId == slotId then
					return slot
				end
			end
			return nil
		end,
	}
end

local function newFakeCmdr()
	local registered: { [string]: any } = {}
	local cmdr = {
		Util = {
			MakeFuzzyFinder = function(entries)
				return function(text)
					local matches = {}
					for _, entry in entries do
						if text == "" or string.find(entry, text, 1, true) then
							table.insert(matches, entry)
						end
					end
					return matches
				end
			end,
			MakeListableType = function(singular)
				return {
					Listable = true,
					Transform = singular.Transform,
					Validate = singular.Validate,
					Autocomplete = singular.Autocomplete,
					Parse = singular.Parse,
					Default = singular.Default,
				}
			end,
		},
		Registry = {
			RegisterType = function(_self, name, definition)
				registered[name] = definition
			end,
		},
	}
	return cmdr, registered
end

local function registerSlotIndex(state: any)
	local cmdr, registered = newFakeCmdr()
	SaveSlotCmdrUtils.registerSlotIndexType(cmdr :: any, newFakeDataService(state))
	return registered.slotIndex, registered.slotIndices
end

describe("SaveSlotCmdrUtils.registerSlotIndexType", function()
	it('resolves "." to the current slot\'s index via Default', function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-2",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
				{ SlotId = "id-2", SlotIndex = 2 },
			},
		})

		expect(slotIndex.Default(FAKE_PLAYER)).toBe("2")
	end)

	it("returns nil from Default when there is no current slot", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = nil,
			slots = {},
		})

		expect(slotIndex.Default(FAKE_PLAYER)).toBeNil()
	end)

	it("returns nil from Default when the remembered slot no longer exists", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-gone",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		expect(slotIndex.Default(FAKE_PLAYER)).toBeNil()
	end)

	it("still fuzzy-finds a literal index through Transform/Parse", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-1",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
				{ SlotId = "id-2", SlotIndex = 2 },
			},
		})

		expect(slotIndex.Parse(slotIndex.Transform("2", FAKE_PLAYER))).toBe(2)
	end)

	it("suggests the reserved ephemeral index while an ephemeral session is active", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-ephemeral",
			ephemeralSlot = { SlotId = "id-ephemeral", SlotIndex = 0, IsEphemeral = true },
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		-- Transform("") is what "*" and autocomplete expand against.
		expect(slotIndex.Transform("", FAKE_PLAYER)).toEqual({ "1", "0" })
		expect(slotIndex.Default(FAKE_PLAYER)).toBe("0")
		expect(slotIndex.Parse(slotIndex.Transform("0", FAKE_PLAYER))).toBe(0)
	end)

	it("leaves the ephemeral index out of the suggestions when no session is active", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-1",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		expect(slotIndex.Transform("", FAKE_PLAYER)).toEqual({ "1" })
	end)

	it("accepts a literal index the executor has no slot for, so other players can be targeted", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-1",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		expect((slotIndex.Validate(slotIndex.Transform("3", FAKE_PLAYER)))).toBe(true)
		expect(slotIndex.Parse(slotIndex.Transform("3", FAKE_PLAYER))).toBe(3)
	end)

	it("rejects text that is not a slot index at all", function()
		local slotIndex = registerSlotIndex({
			lastActiveSlotId = "id-1",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		expect((slotIndex.Validate(slotIndex.Transform("nope", FAKE_PLAYER)))).toBe(false)
		expect((slotIndex.Validate(slotIndex.Transform("-2", FAKE_PLAYER)))).toBe(false)
	end)

	it('exposes Default on the listable type too, so "." works for saveslot-delete', function()
		local _slotIndex, slotIndices = registerSlotIndex({
			lastActiveSlotId = "id-1",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		expect(slotIndices.Default(FAKE_PLAYER)).toBe("1")
	end)
end)

describe("SaveSlotCmdrUtils.formatValue", function()
	it("prints whole numbers without the float tail datastores round-trip them with", function()
		expect(SaveSlotCmdrUtils.formatValue(42.0)).toBe("42")
		expect(SaveSlotCmdrUtils.formatValue(1.5)).toBe("1.50")
	end)

	it("prints a map with sorted keys, so repeated listings read the same", function()
		expect(SaveSlotCmdrUtils.formatValue({ world = 3, coins = 100 })).toBe("{coins = 100, world = 3}")
	end)

	it("prints an array as a list", function()
		expect(SaveSlotCmdrUtils.formatValue({ "a", "b" })).toBe("[a, b]")
	end)

	it("collapses past the depth limit rather than unfolding forever", function()
		expect(SaveSlotCmdrUtils.formatValue({ a = { b = { c = { d = { e = 1 } } } } })).toBe("{a = {b = {c = ...}}}")
	end)
end)

describe("SaveSlotCmdrUtils.formatSummaryLines", function()
	it("prints one line per provider, unwrapping the provider's own table", function()
		expect(SaveSlotCmdrUtils.formatSummaryLines({
			progress = { chapter = 3, percent = 42 },
			currency = 1200,
		})).toEqual({
			"currency: 1200",
			"progress: chapter = 3, percent = 42",
		})
	end)

	it("passes a legacy plain-string summary straight through", function()
		expect(SaveSlotCmdrUtils.formatSummaryLines("Chapters: 1")).toEqual({ "Chapters: 1" })
	end)

	it("has nothing to say about a missing summary", function()
		expect(SaveSlotCmdrUtils.formatSummaryLines(nil)).toEqual({})
	end)
end)

describe("SaveSlotCmdrUtils.formatSlotBlock", function()
	local NOW = 1_754_000_000

	it("prints the summary, playtime and timestamps a listing is read for", function()
		local block = SaveSlotCmdrUtils.formatSlotBlock({
			SlotId = "id-1",
			SlotIndex = 1,
			SlotName = "Alpha",
			CreatedTime = NOW - 86400 * 3,
			LastPlayedTime = NOW - 3600 * 2,
			TimePlayed = 5000,
			PlayCount = 4,
			Summary = { progress = { chapter = 3 } },
		}, "Active", NOW)

		expect(block).toBe(table.concat({
			'"Alpha" (1) — Active',
			"  played 1h 23m, 4 session(s), last played 2025-07-31 20:13 UTC (2h ago)",
			"  created 2025-07-28 22:13 UTC (3d ago)",
			"  progress: chapter = 3",
		}, "\n"))
	end)

	it("prints a never-played slot as its header alone, rather than empty detail lines", function()
		expect(SaveSlotCmdrUtils.formatSlotBlock({ SlotId = "id-2", SlotIndex = 2 }, nil, NOW)).toBe('"Slot 2" (2)')
	end)
end)
