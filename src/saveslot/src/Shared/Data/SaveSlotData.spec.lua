--!nonstrict
--[[
	Covers the Summary metadata field, which is JSON-encoded into a single attribute so a structured,
	provider-keyed summary survives the attribute round-trip (attributes cannot hold tables directly).

	@class SaveSlotData.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SaveSlotData = require("SaveSlotData")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SaveSlotData.Summary", function()
	it("round-trips a structured Summary table through the attribute", function()
		local folder = Instance.new("Folder")

		SaveSlotData.Summary:Set(folder, { coins = 100, world = 3 })
		local value = SaveSlotData.Summary:Get(folder)

		expect(value.coins).toEqual(100)
		expect(value.world).toEqual(3)

		folder:Destroy()
	end)

	it("clears the Summary when set to nil", function()
		local folder = Instance.new("Folder")

		SaveSlotData.Summary:Set(folder, { coins = 1 })
		SaveSlotData.Summary:Set(folder, nil)

		expect(SaveSlotData.Summary:Get(folder)).toBeNil()

		folder:Destroy()
	end)

	it("tolerates a legacy plain-string Summary without erroring", function()
		-- Before the summary was structured it was a single string. A slot saved then still loads: the
		-- value survives (as a string) until the active slot's providers regenerate it as a table.
		local folder = Instance.new("Folder")

		expect(function()
			SaveSlotData.Summary:Set(folder, "Chapters: 1")
		end).never.toThrow()

		local value
		expect(function()
			value = SaveSlotData.Summary:Get(folder)
		end).never.toThrow()
		expect(value).toEqual("Chapters: 1")

		folder:Destroy()
	end)

	it("rejects a non-serializable Summary value", function()
		local folder = Instance.new("Folder")

		expect(function()
			SaveSlotData.Summary:Set(folder, 42 :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)
