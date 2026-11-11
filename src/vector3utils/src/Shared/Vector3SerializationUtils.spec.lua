--!strict
--[[
	@class Vector3SerializationUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Vector3SerializationUtils = require("Vector3SerializationUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Vector3SerializationUtils.serialize", function()
	it("returns the components as a three element list", function()
		expect(Vector3SerializationUtils.serialize(Vector3.new(1, -2, 3.5))).toEqual({ 1, -2, 3.5 })
	end)

	it("serializes the zero vector", function()
		expect(Vector3SerializationUtils.serialize(Vector3.zero)).toEqual({ 0, 0, 0 })
	end)
end)

describe("Vector3SerializationUtils.deserialize", function()
	it("rebuilds the vector from a list", function()
		expect(Vector3SerializationUtils.deserialize({ 1, -2, 3.5 })).toEqual(Vector3.new(1, -2, 3.5))
	end)

	it("round trips through serialize", function()
		local original = Vector3.new(10, 20.25, -30)

		local roundTripped = Vector3SerializationUtils.deserialize(Vector3SerializationUtils.serialize(original))

		expect(roundTripped).toEqual(original)
	end)

	it("errors on a non-table", function()
		expect(function()
			Vector3SerializationUtils.deserialize("1,2,3" :: any)
		end).toThrow("Bad data")
	end)

	it("errors on the wrong number of components", function()
		expect(function()
			Vector3SerializationUtils.deserialize({ 1, 2 })
		end).toThrow("Bad data")

		expect(function()
			Vector3SerializationUtils.deserialize({ 1, 2, 3, 4 })
		end).toThrow("Bad data")
	end)
end)

describe("Vector3SerializationUtils.isSerializedVector3", function()
	it("accepts a three element list", function()
		expect(Vector3SerializationUtils.isSerializedVector3({ 1, 2, 3 })).toBe(true)
		expect(Vector3SerializationUtils.isSerializedVector3(Vector3SerializationUtils.serialize(Vector3.one))).toBe(
			true
		)
	end)

	it("rejects lists of other lengths", function()
		expect(Vector3SerializationUtils.isSerializedVector3({})).toBe(false)
		expect(Vector3SerializationUtils.isSerializedVector3({ 1, 2 })).toBe(false)
		expect(Vector3SerializationUtils.isSerializedVector3({ 1, 2, 3, 4 })).toBe(false)
	end)

	it("rejects non-tables", function()
		expect(Vector3SerializationUtils.isSerializedVector3(nil)).toBe(false)
		expect(Vector3SerializationUtils.isSerializedVector3("1,2,3")).toBe(false)
		expect(Vector3SerializationUtils.isSerializedVector3(Vector3.new(1, 2, 3))).toBe(false)
	end)
end)
