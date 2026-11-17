--!strict
--[[
	@class AdorneeModelBoundingBox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AdorneeModelBoundingBox = require("AdorneeModelBoundingBox")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newModel: () -> Model,
	addPart: (model: Model, size: Vector3?, cframe: CFrame?) -> BasePart,
	newBoundingBox: (model: Model) -> AdorneeModelBoundingBox.AdorneeModelBoundingBox,
	maid: Maid.Maid,
	Destroy: (self: Controller) -> (),
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

		maid = maid,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AdorneeModelBoundingBox.new", function()
	it("has no size until the first update runs", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model)

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		expect(#sizes).toBe(1)
		expect(sizes[1]).toBeNil()

		controller:Destroy()
	end)

	it("has no cframe until the first update runs", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model)

		local boundingBox = controller.newBoundingBox(model)
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		expect(#cframes).toBe(1)
		expect(cframes[1]).toBeNil()

		controller:Destroy()
	end)

	it("matches the engine bounding box after a step", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new(3, 0, 0))

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		StepUtils.deferWait()

		local expectedCFrame, expectedSize = model:GetBoundingBox()

		expect(sizes[#sizes]).toEqual(expectedSize)
		expect(cframes[#cframes]).toEqual(expectedCFrame)

		controller:Destroy()
	end)

	it("collapses several changes in one frame into a single update", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model)

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		StepUtils.deferWait()
		local settledCount = #sizes

		part.Size = Vector3.new(6, 1, 2)
		part.Size = Vector3.new(8, 1, 2)
		part.Size = Vector3.new(10, 1, 2)
		StepUtils.deferWait()

		expect(#sizes).toBe(settledCount + 1)

		controller:Destroy()
	end)
end)

describe("AdorneeModelBoundingBox:ObserveSize", function()
	it("grows when a part is added", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		StepUtils.deferWait()
		local before = sizes[#sizes]

		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new(20, 0, 0))
		StepUtils.deferWait()

		local after = sizes[#sizes]
		local _, expectedSize = model:GetBoundingBox()

		expect(after).toEqual(expectedSize)
		expect(after).never.toEqual(before)

		controller:Destroy()
	end)

	it("updates when a part is resized", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2))

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		StepUtils.deferWait()

		part.Size = Vector3.new(12, 1, 2)
		StepUtils.deferWait()

		local _, expectedSize = model:GetBoundingBox()

		expect(sizes[#sizes]).toEqual(expectedSize)

		controller:Destroy()
	end)

	it("updates when a part is removed", function()
		local controller = setup()

		local model = controller.newModel()
		controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())
		local far = controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new(20, 0, 0))

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		StepUtils.deferWait()
		local before = sizes[#sizes]

		far:Destroy()
		StepUtils.deferWait()

		expect(sizes[#sizes]).never.toEqual(before)

		controller:Destroy()
	end)
end)

describe("AdorneeModelBoundingBox:ObserveCFrame", function()
	it("follows a part that moves", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())

		local boundingBox = controller.newBoundingBox(model)
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		StepUtils.deferWait()
		local before = cframes[#cframes]

		part.CFrame = CFrame.new(0, 50, 0)
		StepUtils.deferWait()

		local after = cframes[#cframes]

		expect(after).never.toEqual(before)
		expect(after.Position.Y).toBeCloseTo(50, 3)

		controller:Destroy()
	end)

	it("follows an unanchored part", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2), CFrame.new())

		local boundingBox = controller.newBoundingBox(model)
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		part.Anchored = false

		part.CFrame = CFrame.new(0, 0, 30)
		StepUtils.deferWait()

		expect(cframes[#cframes].Position.Z).toBeCloseTo(30, 3)

		controller:Destroy()
	end)
end)

describe("AdorneeModelBoundingBox:Destroy", function()
	it("stops emitting once destroyed", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2))

		local boundingBox = controller.newBoundingBox(model)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		StepUtils.deferWait()
		boundingBox:Destroy()

		local settledCount = #sizes

		part.Size = Vector3.new(30, 1, 2)
		StepUtils.deferWait()

		expect(#sizes).toBe(settledCount)

		controller:Destroy()
	end)

	it("stops the unanchored update loop", function()
		local controller = setup()

		local model = controller.newModel()
		local part = controller.addPart(model, Vector3.new(4, 1, 2))
		part.Anchored = false

		local boundingBox = controller.newBoundingBox(model)

		expect(function()
			boundingBox:Destroy()
		end).never.toThrow()

		controller:Destroy()
	end)
end)
