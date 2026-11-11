--!strict
--[[
	@class AdorneePartBoundingBox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AdorneePartBoundingBox = require("AdorneePartBoundingBox")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Record = {
	count: number,
	values: { any },
}

type Controller = {
	newPart: (size: Vector3?, cframe: CFrame?) -> BasePart,
	newBoundingBox: (part: BasePart) -> AdorneePartBoundingBox.AdorneePartBoundingBox,
	collect: (observable: any) -> Record,
	step: (count: number?) -> (),
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newPart = function(size, cframe)
			local part = Instance.new("Part")
			part.Anchored = true
			part.Size = size or Vector3.new(4, 1, 2)
			part.CFrame = cframe or CFrame.new()
			maid:GiveTask(part)
			return part
		end,

		newBoundingBox = function(part)
			return maid:Add(AdorneePartBoundingBox.new(part))
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

describe("AdorneePartBoundingBox.new", function()
	it("rejects an adornee that is not a part", function()
		local controller = setup()

		expect(function()
			AdorneePartBoundingBox.new(Instance.new("Folder") :: any)
		end).toThrow()

		controller:Destroy()
	end)

	it("seeds the size from the part", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveSize())

		expect(record.count).toBe(1)
		expect(record.values[1]).toEqual(Vector3.new(4, 1, 2))

		controller:Destroy()
	end)

	it("seeds the cframe from the part", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new(1, 2, 3))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveCFrame())

		expect(record.count).toBe(1)
		expect(record.values[1]).toEqual(CFrame.new(1, 2, 3))

		controller:Destroy()
	end)
end)

describe("AdorneePartBoundingBox:ObserveSize", function()
	it("emits when the part is resized", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveSize())

		part.Size = Vector3.new(8, 3, 5)
		controller.step()

		expect(record.count).toBe(2)
		expect(record.values[2]).toEqual(Vector3.new(8, 3, 5))

		controller:Destroy()
	end)

	it("does not emit when the size is unchanged", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveSize())

		part.Size = Vector3.new(4, 1, 2)
		controller.step()

		expect(record.count).toBe(1)

		controller:Destroy()
	end)
end)

describe("AdorneePartBoundingBox:ObserveCFrame", function()
	it("emits when the part moves", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new())
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveCFrame())

		part.CFrame = CFrame.new(10, 0, 0)
		controller.step()

		expect(record.count).toBe(2)
		expect(record.values[2]).toEqual(CFrame.new(10, 0, 0))

		controller:Destroy()
	end)

	it("keeps tracking an unanchored part", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new())
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveCFrame())

		part.Anchored = false
		controller.step(2)

		part.CFrame = CFrame.new(0, 25, 0)
		controller.step(2)

		expect(record.values[record.count]).toEqual(CFrame.new(0, 25, 0))

		controller:Destroy()
	end)
end)

describe("AdorneePartBoundingBox:Destroy", function()
	it("stops emitting once destroyed", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveSize())

		boundingBox:Destroy()

		part.Size = Vector3.new(8, 3, 5)
		controller.step()

		expect(record.count).toBe(1)

		controller:Destroy()
	end)
end)
