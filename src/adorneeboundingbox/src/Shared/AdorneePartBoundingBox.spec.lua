--!strict
--[[
	@class AdorneePartBoundingBox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AdorneePartBoundingBox = require("AdorneePartBoundingBox")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newPart: (size: Vector3?, cframe: CFrame?) -> BasePart,
	newBoundingBox: (part: BasePart) -> AdorneePartBoundingBox.AdorneePartBoundingBox,
	maid: Maid.Maid,
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

		maid = maid,
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
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		expect(#sizes).toBe(1)
		expect(sizes[1]).toEqual(Vector3.new(4, 1, 2))

		controller:Destroy()
	end)

	it("seeds the cframe from the part", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new(1, 2, 3))
		local boundingBox = controller.newBoundingBox(part)
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		expect(#cframes).toBe(1)
		expect(cframes[1]).toEqual(CFrame.new(1, 2, 3))

		controller:Destroy()
	end)
end)

describe("AdorneePartBoundingBox:ObserveSize", function()
	it("emits when the part is resized", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		part.Size = Vector3.new(8, 3, 5)

		expect(#sizes).toBe(2)
		expect(sizes[2]).toEqual(Vector3.new(8, 3, 5))

		controller:Destroy()
	end)

	it("does not emit when the size is unchanged", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		part.Size = Vector3.new(4, 1, 2)
		StepUtils.deferWait()

		expect(#sizes).toBe(1)

		controller:Destroy()
	end)
end)

describe("AdorneePartBoundingBox:ObserveCFrame", function()
	it("emits when the part moves", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new())
		local boundingBox = controller.newBoundingBox(part)
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		part.CFrame = CFrame.new(10, 0, 0)

		expect(#cframes).toBe(2)
		expect(cframes[2]).toEqual(CFrame.new(10, 0, 0))

		controller:Destroy()
	end)

	it("keeps tracking an unanchored part", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new())
		local boundingBox = controller.newBoundingBox(part)
		local cframes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveCFrame()))

		part.Anchored = false

		part.CFrame = CFrame.new(0, 25, 0)

		expect(cframes[#cframes]).toEqual(CFrame.new(0, 25, 0))

		controller:Destroy()
	end)
end)

describe("AdorneePartBoundingBox:Destroy", function()
	it("stops emitting once destroyed", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local sizes = controller.maid:Add(ObservableSpy.new(boundingBox:ObserveSize()))

		boundingBox:Destroy()

		part.Size = Vector3.new(8, 3, 5)
		StepUtils.deferWait()

		expect(#sizes).toBe(1)

		controller:Destroy()
	end)
end)
