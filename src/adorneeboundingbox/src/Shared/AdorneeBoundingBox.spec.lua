--!strict
--[[
	@class AdorneeBoundingBox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AdorneeBoundingBox = require("AdorneeBoundingBox")
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
	newModel: (size: Vector3?, cframe: CFrame?) -> Model,
	newHumanoidModel: () -> (Model, Humanoid),
	newTool: () -> Tool,
	newAttachment: (part: BasePart, cframe: CFrame?) -> Attachment,
	newBoundingBox: (adornee: Instance?) -> AdorneeBoundingBox.AdorneeBoundingBox,
	collect: (observable: any) -> Record,
	step: (count: number?) -> (),
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local function newPart(size: Vector3?, cframe: CFrame?): BasePart
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size or Vector3.new(4, 1, 2)
		part.CFrame = cframe or CFrame.new()
		maid:GiveTask(part)
		return part
	end

	local controller: Controller = {
		newPart = newPart,

		newModel = function(size, cframe)
			local model = Instance.new("Model")
			local part = newPart(size, cframe)
			part.Parent = model
			maid:GiveTask(model)
			return model
		end,

		newHumanoidModel = function()
			local model = Instance.new("Model")
			local part = newPart()
			part.Parent = model

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			maid:GiveTask(model)
			return model, humanoid
		end,

		newTool = function()
			local tool = Instance.new("Tool")
			maid:GiveTask(tool)
			return tool
		end,

		newAttachment = function(part, cframe)
			local attachment = Instance.new("Attachment")
			attachment.CFrame = cframe or CFrame.new()
			attachment.Parent = part
			return attachment
		end,

		newBoundingBox = function(adornee)
			return maid:Add(AdorneeBoundingBox.new(adornee))
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

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("AdorneeBoundingBox.new", function()
	it("constructs with no adornee", function()
		local controller = setup()

		local boundingBox = controller.newBoundingBox(nil)

		expect(boundingBox:GetCFrame()).toBeNil()
		expect(boundingBox:GetBoundingBox()).toBeNil()

		controller.destroy()
	end)

	it("does not emit a bounding box with no adornee", function()
		local controller = setup()

		local boundingBox = controller.newBoundingBox(nil)
		local record = controller.collect(boundingBox:ObserveBoundingBox())

		controller.step()

		expect(record.count).toBe(0)

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox with a part adornee", function()
	it("reports the size immediately", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)

		expect(boundingBox:GetSize()).toEqual(Vector3.new(4, 1, 2))

		controller.destroy()
	end)

	it("reports the cframe immediately", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new(1, 2, 3))
		local boundingBox = controller.newBoundingBox(part)

		expect(boundingBox:GetCFrame()).toEqual(CFrame.new(1, 2, 3))

		controller.destroy()
	end)

	it("returns both halves from GetBoundingBox", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2), CFrame.new(1, 2, 3))
		local boundingBox = controller.newBoundingBox(part)

		local data = boundingBox:GetBoundingBox()

		expect(data).never.toBeNil()
		expect((data :: any).Size).toEqual(Vector3.new(4, 1, 2))
		expect((data :: any).CFrame).toEqual(CFrame.new(1, 2, 3))

		controller.destroy()
	end)

	it("emits a bounding box", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2), CFrame.new(1, 2, 3))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveBoundingBox())

		expect(record.count).toBe(1)
		expect(record.values[1].Size).toEqual(Vector3.new(4, 1, 2))
		expect(record.values[1].CFrame).toEqual(CFrame.new(1, 2, 3))

		controller.destroy()
	end)

	it("tracks changes to the part", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)

		part.Size = Vector3.new(9, 9, 9)
		part.CFrame = CFrame.new(0, 100, 0)
		controller.step()

		expect(boundingBox:GetSize()).toEqual(Vector3.new(9, 9, 9))
		expect(boundingBox:GetCFrame()).toEqual(CFrame.new(0, 100, 0))

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox with a model adornee", function()
	it("constructs without throwing", function()
		local controller = setup()

		local model = controller.newModel()

		expect(function()
			controller.newBoundingBox(model)
		end).never.toThrow()

		controller.destroy()
	end)

	it("matches the engine bounding box after a step", function()
		local controller = setup()

		local model = controller.newModel(Vector3.new(4, 1, 2), CFrame.new(3, 0, 0))
		local boundingBox = controller.newBoundingBox(model)

		controller.step()

		local expectedCFrame, expectedSize = model:GetBoundingBox()

		expect(boundingBox:GetSize()).toEqual(expectedSize)
		expect(boundingBox:GetCFrame()).toEqual(expectedCFrame)

		controller.destroy()
	end)

	it("emits a bounding box once measured", function()
		local controller = setup()

		local model = controller.newModel()
		local boundingBox = controller.newBoundingBox(model)
		local record = controller.collect(boundingBox:ObserveBoundingBox())

		controller.step()

		local expectedCFrame, expectedSize = model:GetBoundingBox()

		expect(record.count).never.toBe(0)
		expect(record.values[record.count].Size).toEqual(expectedSize)
		expect(record.values[record.count].CFrame).toEqual(expectedCFrame)

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox with a humanoid adornee", function()
	it("constructs without throwing", function()
		local controller = setup()

		local _model, humanoid = controller.newHumanoidModel()

		expect(function()
			controller.newBoundingBox(humanoid)
		end).never.toThrow()

		controller.destroy()
	end)

	it("uses the bounding box of the parent model", function()
		local controller = setup()

		local model, humanoid = controller.newHumanoidModel()
		local boundingBox = controller.newBoundingBox(humanoid)

		controller.step()

		local _expectedCFrame, expectedSize = model:GetBoundingBox()

		expect(boundingBox:GetSize()).toEqual(expectedSize)

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox with a tool adornee", function()
	it("has no cframe while the tool has no handle", function()
		local controller = setup()

		local tool = controller.newTool()
		local boundingBox = controller.newBoundingBox(tool)

		controller.step()

		expect(boundingBox:GetCFrame()).toBeNil()

		controller.destroy()
	end)

	it("uses the handle once it exists", function()
		local controller = setup()

		local tool = controller.newTool()
		local boundingBox = controller.newBoundingBox(tool)

		local handle = controller.newPart(Vector3.new(1, 2, 3), CFrame.new(5, 0, 0))
		handle.Name = "Handle"
		handle.Parent = tool
		controller.step()

		expect(boundingBox:GetSize()).toEqual(Vector3.new(1, 2, 3))
		expect(boundingBox:GetCFrame()).toEqual(CFrame.new(5, 0, 0))

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox with an attachment adornee", function()
	it("reports a zero size", function()
		local controller = setup()

		local part = controller.newPart()
		local attachment = controller.newAttachment(part)
		local boundingBox = controller.newBoundingBox(attachment)

		controller.step()

		expect(boundingBox:GetSize()).toEqual(Vector3.zero)

		controller.destroy()
	end)

	it("reports the world cframe of the attachment", function()
		local controller = setup()

		local part = controller.newPart(nil, CFrame.new(10, 0, 0))
		local attachment = controller.newAttachment(part, CFrame.new(0, 5, 0))
		local boundingBox = controller.newBoundingBox(attachment)

		controller.step()

		local cframe = boundingBox:GetCFrame()

		expect(cframe).never.toBeNil()
		expect((cframe :: CFrame).Position).toEqual(Vector3.new(10, 5, 0))

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox with an unsupported adornee", function()
	it("has no cframe", function()
		local controller = setup()

		local folder = Instance.new("Folder")
		local boundingBox = controller.newBoundingBox(folder)

		controller.step()

		expect(boundingBox:GetCFrame()).toBeNil()

		folder:Destroy()
		controller.destroy()
	end)

	it("never emits a bounding box", function()
		local controller = setup()

		local folder = Instance.new("Folder")
		local boundingBox = controller.newBoundingBox(folder)
		local record = controller.collect(boundingBox:ObserveBoundingBox())

		controller.step()

		expect(record.count).toBe(0)

		folder:Destroy()
		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox:SetAdornee", function()
	it("rejects a value that is not an instance", function()
		local controller = setup()

		local boundingBox = controller.newBoundingBox(nil)

		expect(function()
			boundingBox:SetAdornee("not an instance" :: any)
		end).toThrow()

		controller.destroy()
	end)

	it("accepts nil", function()
		local controller = setup()

		local boundingBox = controller.newBoundingBox(nil)

		expect(function()
			boundingBox:SetAdornee(nil)
		end).never.toThrow()

		controller.destroy()
	end)

	it("starts tracking the new adornee", function()
		local controller = setup()

		local boundingBox = controller.newBoundingBox(nil)
		local part = controller.newPart(Vector3.new(7, 7, 7))

		boundingBox:SetAdornee(part)

		expect(boundingBox:GetSize()).toEqual(Vector3.new(7, 7, 7))

		controller.destroy()
	end)

	it("swaps between adornees", function()
		local controller = setup()

		local first = controller.newPart(Vector3.new(4, 1, 2))
		local second = controller.newPart(Vector3.new(8, 8, 8))
		local boundingBox = controller.newBoundingBox(first)

		boundingBox:SetAdornee(second)

		expect(boundingBox:GetSize()).toEqual(Vector3.new(8, 8, 8))

		controller.destroy()
	end)

	it("returns a cleanup that stops tracking", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(nil)

		local cleanup = boundingBox:SetAdornee(part)
		cleanup()

		part.Size = Vector3.new(20, 20, 20)
		controller.step()

		expect(boundingBox:GetSize()).never.toEqual(Vector3.new(20, 20, 20))

		controller.destroy()
	end)

	it("returns a cleanup that leaves a newer adornee alone", function()
		local controller = setup()

		local first = controller.newPart(Vector3.new(4, 1, 2))
		local second = controller.newPart(Vector3.new(8, 8, 8))
		local boundingBox = controller.newBoundingBox(nil)

		local cleanup = boundingBox:SetAdornee(first)
		boundingBox:SetAdornee(second)
		cleanup()

		expect(boundingBox:GetSize()).toEqual(Vector3.new(8, 8, 8))

		controller.destroy()
	end)
end)

describe("AdorneeBoundingBox:Destroy", function()
	it("stops tracking the adornee", function()
		local controller = setup()

		local part = controller.newPart(Vector3.new(4, 1, 2))
		local boundingBox = controller.newBoundingBox(part)
		local record = controller.collect(boundingBox:ObserveBoundingBox())

		boundingBox:Destroy()

		part.Size = Vector3.new(20, 20, 20)
		controller.step()

		expect(record.count).toBe(1)

		controller.destroy()
	end)

	it("does not throw while tracking a model", function()
		local controller = setup()

		local model = controller.newModel()
		local boundingBox = controller.newBoundingBox(model)

		controller.step()

		expect(function()
			boundingBox:Destroy()
		end).never.toThrow()

		controller.destroy()
	end)
end)
