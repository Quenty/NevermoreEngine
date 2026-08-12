--!strict
--[[
	@class AdorneeModelBoundingBox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AdorneeModelBoundingBox = require("AdorneeModelBoundingBox")
local Jest = require("Jest")
local Maid = require("Maid")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Record = {
	count: number,
	values: { any },
}

type Controller = {
	newModel: () -> Model,
	addPart: (model: Model, size: Vector3?, cframe: CFrame?) -> BasePart,
	newBoundingBox: (model: Model) -> AdorneeModelBoundingBox.AdorneeModelBoundingBox,
	collect: (observable: any) -> Record,
	step: (count: number?) -> (),
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newModel = function()
			local model = Instance.new("Model")
			maid:GiveTask(model)
			return model
		end,

		addPart = function(model, size, cframe)
			local part = Instance.new("Part")
			part.Anchored = true
			part.Size = size or Vector3.new(4, 1, 2)
			part.CFrame = cframe or CFrame.new()
			part.Parent = model
			return part
		end,

		newBoundingBox = function(model)
			return maid:Add(AdorneeModelBoundingBox.new(model))
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

		destroy = function()
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("AdorneeModelBoundingBox.new", function()
	it("has no size until the first update runs", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model)

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveSize())

		expect(record.count).toBe(1)
		expect(record.values[1]).toBeNil()

		controller.destroy()
	end)

	it("has no cframe until the first update runs", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model)

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveCFrame())

		expect(record.count).toBe(1)
		expect(record.values[1]).toBeNil()

		controller.destroy()
	end)

	it("matches the engine bounding box after a step", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new(3, 0, 0))

		local boundingBox = controller.newBoundingBox(model)
		local sizeRecord = controller.collect(boundingBox:ObserveSize())
		local cframeRecord = controller.collect(boundingBox:ObserveCFrame())

		controller.step()

		local expectedCFrame, expectedSize = model:GetBoundingBox()

		expect(sizeRecord.values[sizeRecord.count]).toEqual(expectedSize)
		expect(cframeRecord.values[cframeRecord.count]).toEqual(expectedCFrame)

		controller.destroy()
	end)

	it("collapses several changes in one frame into a single update", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model)

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveSize())

		controller.step()
		local settledCount = record.count

		part.Size = Vector3.new(6, 1, 2)
		part.Size = Vector3.new(8, 1, 2)
		part.Size = Vector3.new(10, 1, 2)
		controller.step()

		expect(record.count).toBe(settledCount + 1)

		controller.destroy()
	end)
end)

describe("AdorneeModelBoundingBox:ObserveSize", function()
	it("grows when a part is added", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveSize())

		controller.step()
		local before = record.values[record.count]

		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new(20, 0, 0))
		controller.step()

		local after = record.values[record.count]
		local _, expectedSize = model:GetBoundingBox()

		expect(after).toEqual(expectedSize)
		expect(after).never.toEqual(before)

		controller.destroy()
	end)

	it("updates when a part is resized", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2))

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveSize())

		controller.step()

		part.Size = Vector3.new(12, 1, 2)
		controller.step()

		local _, expectedSize = model:GetBoundingBox()

		expect(record.values[record.count]).toEqual(expectedSize)

		controller.destroy()
	end)

	it("updates when a part is removed", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())
		local far = controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new(20, 0, 0))

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveSize())

		controller.step()
		local before = record.values[record.count]

		far:Destroy()
		controller.step()

		expect(record.values[record.count]).never.toEqual(before)

		controller.destroy()
	end)
end)

describe("AdorneeModelBoundingBox:ObserveCFrame", function()
	it("follows a part that moves", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveCFrame())

		controller.step()
		local before = record.values[record.count]

		part.CFrame = CFrame.new(0, 50, 0)
		controller.step()

		local after = record.values[record.count]

		expect(after).never.toEqual(before)
		expect(after.Position.Y).toBeCloseTo(50, 3)

		controller.destroy()
	end)

	it("follows an unanchored part", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveCFrame())

		part.Anchored = false
		controller.step(2)

		part.CFrame = CFrame.new(0, 0, 30)
		controller.step(2)

		expect(record.values[record.count].Position.Z).toBeCloseTo(30, 3)

		controller.destroy()
	end)
end)

describe("AdorneeModelBoundingBox:Destroy", function()
	it("stops emitting once destroyed", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2))

		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveSize())

		controller.step()
		boundingBox:Destroy()

		local settledCount = record.count

		part.Size = Vector3.new(30, 1, 2)
		controller.step(2)

		expect(record.count).toBe(settledCount)

		controller.destroy()
	end)

	it("stops the unanchored update loop", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2))
		part.Anchored = false

		local boundingBox = controller.newBoundingBox(model)
		controller.step(2)

		expect(function()
			boundingBox:Destroy()
		end).never.toThrow()

		controller.step(2)

		controller.destroy()
	end)
end)
