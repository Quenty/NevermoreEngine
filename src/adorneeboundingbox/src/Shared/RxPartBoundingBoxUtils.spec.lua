--!strict
--[[
	@class RxPartBoundingBoxUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local RxPartBoundingBoxUtils = require("RxPartBoundingBoxUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Record = {
	count: number,
	values: { any },
}

type Controller = {
	newPart: (cframe: CFrame?) -> BasePart,
	collect: (observable: any) -> Record,
	step: (count: number?) -> (),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newPart = function(cframe)
			local part = Instance.new("Part")
			part.Anchored = true
			part.CFrame = cframe or CFrame.new()
			maid:GiveTask(part)
			return part
		end,

		collect = function(observable)
			local record: Record = {
				count = 0,
				values = {},
			}

			maid:GiveTask(observable:Subscribe(function(value)
				record.count += 1
				record.values[record.count] = value
			end))

			return record
		end,

		step = function(count)
			for _ = 1, count or 1 do
				task.wait()
			end
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxPartBoundingBoxUtils.observePartCFrame", function()
	it("rejects an adornee that is not a part", function()
		local controller = setup()

		expect(function()
			RxPartBoundingBoxUtils.observePartCFrame(Instance.new("Folder") :: any)
		end).toThrow()

		controller:Destroy()
	end)

	it("emits the current cframe on subscribe", function()
		local controller = setup()

		local part = controller.newPart(CFrame.new(1, 2, 3))
		local record = controller.collect(RxPartBoundingBoxUtils.observePartCFrame(part))

		expect(record.count).toBe(1)
		expect(record.values[1]).toEqual(CFrame.new(1, 2, 3))

		controller:Destroy()
	end)

	it("emits when the part moves", function()
		local controller = setup()

		local part = controller.newPart(CFrame.new())
		local record = controller.collect(RxPartBoundingBoxUtils.observePartCFrame(part))

		part.CFrame = CFrame.new(0, 40, 0)
		controller.step()

		expect(record.count).toBe(2)
		expect(record.values[2]).toEqual(CFrame.new(0, 40, 0))

		controller:Destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()

		local part = controller.newPart(CFrame.new())

		local count = 0
		local sub = RxPartBoundingBoxUtils.observePartCFrame(part):Subscribe(function()
			count += 1
		end)
		sub:Destroy()

		part.CFrame = CFrame.new(0, 40, 0)
		controller.step()

		expect(count).toBe(1)

		controller:Destroy()
	end)
end)
