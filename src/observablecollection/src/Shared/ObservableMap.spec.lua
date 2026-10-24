--!strict
--[[
	@class ObservableMap.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ObservableMap = require("ObservableMap")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- The skip depends on where keys hash, so one walk rarely shows it
local TRIALS = 100

type Controller = {
	newMapWithKeys: (count: number) -> (ObservableMap.ObservableMap<any, boolean>, { any }),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newMapWithKeys = function(count)
			local map = maid:Add(ObservableMap.new())
			local keys = {}
			for _ = 1, count do
				local key = {}
				table.insert(keys, key)
				map:Set(key, true)
			end
			return map, keys
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	return controller
end

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
		expect(observableMap:Get(false :: any)).toEqual(nil)
		observableMap:Set(false :: any, "Hello")
		expect(observableMap:Get(false :: any)).toEqual("Hello")
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

describe("ObservableMap.ObservePairsBrio", function()
	it("emits every existing key when the subscriber adds keys", function()
		local controller = setup()

		for _ = 1, TRIALS do
			local map, keys = controller.newMapWithKeys(5)
			local seen = {}
			map:ObservePairsBrio():Subscribe(function(brio)
				local key = brio:GetValue()
				if table.find(keys, key) then
					table.insert(seen, key)
					for _ = 1, 3 do
						map:Set({}, true)
					end
				end
			end)

			expect(#seen).toBe(#keys)
		end

		controller:Destroy()
	end)

	it("skips a key the subscriber removes before the walk reaches it", function()
		local controller = setup()
		local map, keys = controller.newMapWithKeys(5)

		local seen = {}
		map:ObservePairsBrio():Subscribe(function(brio)
			table.insert(seen, (brio:GetValue()))
			for _, key in keys do
				map:Remove(key)
			end
		end)

		expect(#seen).toBe(1)

		controller:Destroy()
	end)
end)
