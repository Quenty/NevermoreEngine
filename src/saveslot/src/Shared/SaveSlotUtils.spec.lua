--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SaveSlotUtils = require("SaveSlotUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local NOW = 1_754_000_000

local function metadata(fields: { [string]: any }): any
	local result: { [string]: any } = { SlotId = "slot-1", SlotIndex = 1 }
	for key, value in fields do
		result[key] = value
	end
	return result
end

describe("SaveSlotUtils.getTimePlayed", function()
	it("returns the credited total for an inactive slot", function()
		local slot = metadata({ TimePlayed = 500, LastSessionLength = 120, LastPlayedTime = NOW - 3600 })

		expect(SaveSlotUtils.getTimePlayed(slot, false, NOW)).toBe(500)
	end)

	it("returns zero for a slot that has never been played", function()
		expect(SaveSlotUtils.getTimePlayed(metadata({}), false, NOW)).toBe(0)
		expect(SaveSlotUtils.getTimePlayed(metadata({}), true, NOW)).toBe(0)
	end)

	it("counts the running session from the moment the active slot was selected", function()
		local slot = metadata({ TimePlayed = 500, LastSessionLength = 0, LastPlayedTime = NOW - 90 })

		expect(SaveSlotUtils.getTimePlayed(slot, true, NOW)).toBe(590)
	end)

	it("does not double count the part of the session a flush already credited", function()
		-- 60s of a 90s session has been flushed into the total
		local slot = metadata({ TimePlayed = 560, LastSessionLength = 60, LastPlayedTime = NOW - 90 })

		expect(SaveSlotUtils.getTimePlayed(slot, true, NOW)).toBe(590)
	end)

	it("never reads below the credited total when the clock is behind the server", function()
		local slot = metadata({ TimePlayed = 560, LastSessionLength = 60, LastPlayedTime = NOW - 90 })

		expect(SaveSlotUtils.getTimePlayed(slot, true, NOW - 45)).toBe(560)
	end)

	it("starts a first session from zero", function()
		local slot = metadata({ LastPlayedTime = NOW - 30 })

		expect(SaveSlotUtils.getTimePlayed(slot, true, NOW)).toBe(30)
	end)
end)
