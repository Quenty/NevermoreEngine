--!nonstrict
--[[
	Characterization tests for DataStoreSnapshotUtils.
	@class DataStoreSnapshotUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreDeleteToken = require("DataStoreDeleteToken")
local DataStoreSnapshotUtils = require("DataStoreSnapshotUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStoreSnapshotUtils.isEmptySnapshot(snapshot)", function()
	it("should return true for an empty table", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({})).toEqual(true)
	end)

	it("should return false for a table with array entries", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({ 1, 2, 3 })).toEqual(false)
	end)

	it("should return false for a table with a single dictionary entry", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({ key = "value" })).toEqual(false)
	end)

	it("should return false for a table with a false value", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({ key = false })).toEqual(false)
	end)

	it("should return false for a nested table", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({ nested = {} })).toEqual(false)
	end)

	it("should return false for a table holding an empty nested table by index", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({ {} })).toEqual(false)
	end)

	it("should return true for a frozen empty table", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(table.freeze({}))).toEqual(true)
	end)

	it("should return false for a frozen non-empty table", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(table.freeze({ key = "value" }))).toEqual(false)
	end)

	it("should return false for the delete token", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(DataStoreDeleteToken)).toEqual(false)
	end)

	it("should return false for nil", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(nil)).toEqual(false)
	end)

	it("should return false for a string", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot("")).toEqual(false)
		expect(DataStoreSnapshotUtils.isEmptySnapshot("hello")).toEqual(false)
	end)

	it("should return false for a number", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(0)).toEqual(false)
		expect(DataStoreSnapshotUtils.isEmptySnapshot(5)).toEqual(false)
	end)

	it("should return false for a boolean", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(true)).toEqual(false)
		expect(DataStoreSnapshotUtils.isEmptySnapshot(false)).toEqual(false)
	end)

	it("should return false for a function", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(function() end)).toEqual(false)
	end)

	it("should return a boolean type, never nil", function()
		expect(DataStoreSnapshotUtils.isEmptySnapshot({})).never.toBeNil()
		expect(DataStoreSnapshotUtils.isEmptySnapshot(nil)).never.toBeNil()
		expect(type(DataStoreSnapshotUtils.isEmptySnapshot({}))).toEqual("boolean")
		expect(type(DataStoreSnapshotUtils.isEmptySnapshot(nil))).toEqual("boolean")
	end)

	it("should not throw for any input type", function()
		expect(function()
			DataStoreSnapshotUtils.isEmptySnapshot(nil)
			DataStoreSnapshotUtils.isEmptySnapshot({})
			DataStoreSnapshotUtils.isEmptySnapshot(DataStoreDeleteToken)
			DataStoreSnapshotUtils.isEmptySnapshot("string")
		end).never.toThrow()
	end)
end)
