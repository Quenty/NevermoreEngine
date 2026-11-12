--!strict
--[[
	@class ObservableSet.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ObservableSet = require("ObservableSet")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- The skip depends on where items hash, so one walk rarely shows it
local TRIALS = 100

type Controller = {
	newSetWithItems: (count: number) -> (ObservableSet.ObservableSet<any>, { any }),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newSetWithItems = function(count)
			local set = maid:Add(ObservableSet.new())
			local items = {}
			for _ = 1, count do
				local item = {}
				table.insert(items, item)
				set:Add(item)
			end
			return set, items
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("ObservableSet.ObserveItemsBrio", function()
	it("emits every existing item when the subscriber adds items", function()
		local controller = setup()

		for _ = 1, TRIALS do
			local set, items = controller.newSetWithItems(5)
			local seen = {}
			set:ObserveItemsBrio():Subscribe(function(brio)
				local item = brio:GetValue()
				if table.find(items, item) then
					table.insert(seen, item)
					for _ = 1, 3 do
						set:Add({})
					end
				end
			end)

			expect(#seen).toBe(#items)
		end

		controller:Destroy()
	end)

	it("skips an item the subscriber removes before the walk reaches it", function()
		local controller = setup()
		local set, items = controller.newSetWithItems(5)

		local seen = {}
		set:ObserveItemsBrio():Subscribe(function(brio)
			table.insert(seen, brio:GetValue())
			for _, item in items do
				set:Remove(item)
			end
		end)

		expect(#seen).toBe(1)

		controller:Destroy()
	end)
end)
