--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SaveSlotCodeUtils = require("SaveSlotCodeUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SaveSlotCodeUtils.generateDefaultCode", function()
	it("produces a date-prefixed, hyphenated code carrying the state and user", function()
		local code = SaveSlotCodeUtils.generateDefaultCode({ userName = "Jonnen", slotName = "World3" })
		expect(type(code)).toEqual("string")
		expect(string.match(code, "^%d%d%d%d%d%d%d%d%-") ~= nil).toEqual(true)
		expect(string.find(code, "world3", 1, true) ~= nil).toEqual(true)
		expect(string.find(code, "jonnen", 1, true) ~= nil).toEqual(true)
	end)

	it("sanitizes to a datastore-safe slug (lowercase alphanumeric + hyphens, length-capped)", function()
		local code = SaveSlotCodeUtils.generateDefaultCode({ userName = "Weird Name!!", slotName = "A/B\\C" })
		expect(string.match(code, "^[a-z0-9%-]+$") ~= nil).toEqual(true)
		expect(#code <= 50).toEqual(true)
	end)

	it("varies the token across calls so codes do not collide", function()
		local a = SaveSlotCodeUtils.generateDefaultCode({ userName = "x", slotName = "y" })
		local b = SaveSlotCodeUtils.generateDefaultCode({ userName = "x", slotName = "y" })
		expect(a).never.toEqual(b)
	end)

	it("falls back to safe defaults when fields are missing", function()
		local code = SaveSlotCodeUtils.generateDefaultCode({})
		expect(type(code)).toEqual("string")
		expect(#code > 0).toEqual(true)
		expect(string.match(code, "^[a-z0-9%-]+$") ~= nil).toEqual(true)
	end)

	it("uses the slot index when no name is given", function()
		local code = SaveSlotCodeUtils.generateDefaultCode({ slotIndex = 4, userName = "x" })
		expect(string.find(code, "slot4", 1, true) ~= nil).toEqual(true)
	end)
end)
