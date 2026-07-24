--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotExportUtils = require("SaveSlotExportUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SaveSlotExportUtils.isMainSlotIndex", function()
	it("is true for the default slot index", function()
		expect(SaveSlotExportUtils.isMainSlotIndex(SaveSlotConstants.DEFAULT_SLOT_INDEX)).toEqual(true)
	end)

	it("is false for non-main indices", function()
		expect(SaveSlotExportUtils.isMainSlotIndex(SaveSlotConstants.DEFAULT_SLOT_INDEX + 1)).toEqual(false)
		expect(SaveSlotExportUtils.isMainSlotIndex(0)).toEqual(false)
	end)
end)

describe("SaveSlotExportUtils.isSaveSlotExport", function()
	it("accepts a minimal export", function()
		expect(SaveSlotExportUtils.isSaveSlotExport({ data = {} })).toEqual(true)
	end)

	it("accepts an export carrying metadata", function()
		expect(SaveSlotExportUtils.isSaveSlotExport({ data = { Coins = 5 }, slotName = "Hero", summary = { pct = 1 } })).toEqual(
			true
		)
	end)

	it("rejects non-tables", function()
		expect(SaveSlotExportUtils.isSaveSlotExport(nil)).toEqual(false)
		expect(SaveSlotExportUtils.isSaveSlotExport(5)).toEqual(false)
		expect(SaveSlotExportUtils.isSaveSlotExport("x")).toEqual(false)
	end)

	it("rejects a missing or malformed data field", function()
		expect(SaveSlotExportUtils.isSaveSlotExport({})).toEqual(false)
		expect(SaveSlotExportUtils.isSaveSlotExport({ data = 5 })).toEqual(false)
	end)

	it("rejects a non-string slotName", function()
		expect(SaveSlotExportUtils.isSaveSlotExport({ data = {}, slotName = 5 })).toEqual(false)
	end)
end)

describe("SaveSlotExportUtils.create", function()
	it("carries data and metadata through and is a valid export", function()
		local export = SaveSlotExportUtils.create({ Coins = 3 }, "Hero", { pct = 50 })
		expect(export.data.Coins).toEqual(3)
		expect(export.slotName).toEqual("Hero")
		expect(export.summary.pct).toEqual(50)
		expect(SaveSlotExportUtils.isSaveSlotExport(export)).toEqual(true)
	end)

	it("allows omitted metadata", function()
		local export = SaveSlotExportUtils.create({})
		expect(export.slotName).toBeNil()
		expect(export.summary).toBeNil()
		expect(SaveSlotExportUtils.isSaveSlotExport(export)).toEqual(true)
	end)
end)
