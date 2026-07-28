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
