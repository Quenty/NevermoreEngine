--!strict
--[[
	Coverage for the "slotIndex"/"slotIndices" Cmdr types, focused on the "." shorthand (Cmdr's
	Default callback) that resolves to the player's current slot -- the active slot, or the last one
	they played. Cmdr itself is stubbed so the type's Default/Transform can be exercised directly.

	@class SaveSlotCmdrUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SaveSlotCmdrUtils = require("SaveSlotCmdrUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- A stand-in player. The fake data service keys off nothing, so any sentinel works.
local FAKE_PLAYER = newproxy(false)

-- Minimal SaveSlotDataService driven by a mutable `state`. Mirrors the real methods the type uses.
local function newFakeDataService(state)
	return {
		GetSlotList = function(_self, _player)
			return state.slots
		end,
		GetLastActiveSlotId = function(_self, _player)
			return state.lastActiveSlotId
		end,
		GetSlotMetadata = function(_self, _player, slotId)
			for _, slot in state.slots do
				if slot.SlotId == slotId then
					return slot
				end
			end
			return nil
		end,
	}
end

-- Enough of Cmdr for registerSlotIndexType: a substring fuzzy finder, a listable wrapper that copies
-- fields the way the real Util.MakeListableType does (so Default propagation is exercised), and a
-- registry that captures the registered definitions.
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

-- Registers the types against a fake data service backed by `state` and returns the registered types.
local function registerSlotIndex(state)
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
		-- Last-active points at a deleted slot: GetSlotMetadata finds nothing, so "." resolves to nothing.
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

	it('exposes Default on the listable type too, so "." works for delete-save-slot', function()
		local _slotIndex, slotIndices = registerSlotIndex({
			lastActiveSlotId = "id-1",
			slots = {
				{ SlotId = "id-1", SlotIndex = 1 },
			},
		})

		expect(slotIndices.Default(FAKE_PLAYER)).toBe("1")
	end)
end)
