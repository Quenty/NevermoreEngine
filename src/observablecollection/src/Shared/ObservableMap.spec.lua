--[[
	@class ObservableMap.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local ObservableMap = require("ObservableMap")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ObservableMap.new()", function()
	local observableMap = ObservableMap.new()

	it("should return nil for unset values", function()
		expect(observableMap:Get("a")).toEqual(nil)
	end)

	it("should allow setting a value", function()
		expect(observableMap:GetCount()).toEqual(0)

		observableMap:Set("a", "Hello World")

		expect(observableMap:Get("a")).toEqual("Hello World")
		expect(observableMap:GetCount()).toEqual(1)
	end)

	it("should overwrite values", function()
		expect(observableMap:Get("a")).toEqual("Hello World")

		observableMap:Set("a", "Hello World 2")

		expect(observableMap:Get("a")).toEqual("Hello World 2")
	end)

	it("should allow false as a key", function()
		expect(observableMap:Get(false)).toEqual(nil)
		observableMap:Set(false, "Hello")
		expect(observableMap:Get(false)).toEqual("Hello")
	end)

	it("should fire off events for a specific key", function()
		local seen = {}
		local sub = observableMap:ObserveValueForKey("c"):Subscribe(function(value)
			table.insert(seen, value)
		end)
		observableMap:Set("c", "Hello")

		sub:Destroy()

		expect(#seen).toEqual(1)
		expect(seen[1]).toEqual("Hello")
	end)

	it("should fire off events for all keys", function()
		local seen = {}
		local sub = observableMap:ObserveValuesBrio():Subscribe(function(value)
			table.insert(seen, value)
		end)
		observableMap:Set("d", "Hello")

		expect(#seen).toEqual(4)
		expect(seen[4]:GetValue()).toEqual("Hello")
		expect(seen[4]:IsDead()).toEqual(false)

		sub:Destroy()

		expect(#seen).toEqual(4)
		expect(seen[4]:IsDead()).toEqual(true)
	end)

	it("should clean up", function()
		observableMap:Destroy()
	end)
end)