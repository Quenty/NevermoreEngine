--!strict
--[[
	@class ObservableCountingMap.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ObservableCountingMap = require("ObservableCountingMap")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- The skip depends on where keys hash, so one walk rarely shows it
local TRIALS = 100

type Controller = {
	newMapWithKeys: (count: number) -> (ObservableCountingMap.ObservableCountingMap<any>, { any }),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newMapWithKeys = function(count)
			local map = maid:Add(ObservableCountingMap.new())
			local keys = {}
			for _ = 1, count do
				local key = {}
				table.insert(keys, key)
				map:Add(key)
			end
			return map, keys
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("ObservableCountingMap.new()", function()
	local observableCountingMap = ObservableCountingMap.new()

	it("should return 0 for unset values", function()
		expect(observableCountingMap:Get("a")).toEqual(0)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(0)
	end)

	it("should allow you to add to a value", function()
		expect(observableCountingMap:Get("a")).toEqual(0)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(0)
		observableCountingMap:Add("a", 5)
		expect(observableCountingMap:Get("a")).toEqual(5)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(1)
	end)

	it("should allow you to add to a value that is already defined", function()
		expect(observableCountingMap:Get("a")).toEqual(5)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(1)
		observableCountingMap:Add("a", 5)
		expect(observableCountingMap:Get("a")).toEqual(10)
		expect(observableCountingMap:GetTotalKeyCount()).toEqual(1)
	end)

	it("should clean up", function()
		observableCountingMap:Destroy()
	end)
end)

describe("ObservableCountingMap.ObserveKeysBrio", function()
	it("emits every existing key when the subscriber adds keys", function()
		local controller = setup()

		for _ = 1, TRIALS do
			local map, keys = controller.newMapWithKeys(5)
			local seen = {}
			map:ObserveKeysBrio():Subscribe(function(brio)
				local key = brio:GetValue()
				if table.find(keys, key) then
					table.insert(seen, key)
					for _ = 1, 3 do
						map:Add({})
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
		map:ObserveKeysBrio():Subscribe(function(brio)
			table.insert(seen, brio:GetValue())
			for _, key in keys do
				map:Remove(key)
			end
		end)

		expect(#seen).toBe(1)

		controller:Destroy()
	end)
end)

describe("ObservableCountingMap.ObservePairsBrio", function()
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
						map:Add({})
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
