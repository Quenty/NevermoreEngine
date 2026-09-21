--!strict
--[[
	@class FabricBallSocketUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local FabricBallSocketUtils = require("FabricBallSocketUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Vector3Utils = require("Vector3Utils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local WEDGE_SIZE = Vector3.new(1, 4, 4)

local TOP_CORNER = Vector3.new(0, 2, 2)
local BOTTOM_BACK_CORNER = Vector3.new(0, -2, -2)

local EPSILON = 1e-4

type Controller = {
	newWedge: (cframe: CFrame?) -> WedgePart,
	newModel: () -> Model,
	newFolder: () -> Folder,
	newCornerPair: () -> (Model, WedgePart, WedgePart),
	newQuad: () -> (Model, WedgePart, WedgePart),
	newSeparatedPair: () -> (Model, WedgePart, WedgePart),
	getDescendantsOfClass: (adornee: Instance, className: string) -> { Instance },
	isSameRotation: (cframe0: CFrame, cframe1: CFrame) -> boolean,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local function newWedge(cframe: CFrame?): WedgePart
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.Size = WEDGE_SIZE
		wedge.CFrame = cframe or CFrame.new()
		maid:GiveTask(wedge)
		return wedge
	end

	local function newModel(): Model
		local model = Instance.new("Model")
		maid:GiveTask(model)
		return model
	end

	local controller: Controller = {
		newWedge = newWedge,
		newModel = newModel,

		newFolder = function()
			local folder = Instance.new("Folder")
			maid:GiveTask(folder)
			return folder
		end,

		newCornerPair = function()
			local model = newModel()

			local first = newWedge(CFrame.new())
			first.Name = "First"
			first.Parent = model

			local second = newWedge(CFrame.new(0, 0, -4))
			second.Name = "Second"
			second.Parent = model

			return model, first, second
		end,

		newQuad = function()
			local model = newModel()

			local first = newWedge(CFrame.new())
			first.Name = "First"
			first.Parent = model

			local second = newWedge(CFrame.Angles(math.pi, 0, 0))
			second.Name = "Second"
			second.Parent = model

			return model, first, second
		end,

		newSeparatedPair = function()
			local model = newModel()

			local first = newWedge(CFrame.new())
			first.Name = "First"
			first.Parent = model

			local second = newWedge(CFrame.new(0, 0, 100))
			second.Name = "Second"
			second.Parent = model

			return model, first, second
		end,

		getDescendantsOfClass = function(adornee, className)
			local found = {}
			for _, descendant in adornee:GetDescendants() do
				if descendant:IsA(className) then
					table.insert(found, descendant)
				end
			end
			return found
		end,

		isSameRotation = function(cframe0, cframe1)
			return Vector3Utils.areClose(cframe0.LookVector, cframe1.LookVector, EPSILON)
				and Vector3Utils.areClose(cframe0.UpVector, cframe1.UpVector, EPSILON)
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("FabricBallSocketUtils.create", function()
	it("attaches every corner of every wedge", function()
		local controller = setup()
		local model = controller.newCornerPair()

		FabricBallSocketUtils.create(model)

		expect(#controller.getDescendantsOfClass(model, "Attachment")).toBe(6)

		controller:Destroy()
	end)

	it("joints wedges that meet at a corner", function()
		local controller = setup()
		local model, first, second = controller.newCornerPair()

		local joints = FabricBallSocketUtils.create(model)

		expect(#joints).toBe(1)

		local attachment0 = joints[1].Attachment0 :: Attachment
		local attachment1 = joints[1].Attachment1 :: Attachment

		expect(attachment0.Parent).toBe(second)
		expect(attachment1.Parent).toBe(first)
		expect(Vector3Utils.areClose(attachment0.WorldPosition, BOTTOM_BACK_CORNER, EPSILON)).toBe(true)
		expect(Vector3Utils.areClose(attachment1.WorldPosition, BOTTOM_BACK_CORNER, EPSILON)).toBe(true)

		controller:Destroy()
	end)

	it("creates one joint for each shared corner", function()
		local controller = setup()
		local model = controller.newQuad()

		local joints = FabricBallSocketUtils.create(model)

		expect(#joints).toBe(2)

		local jointedAt = {}
		for _, joint in joints do
			local attachment0 = joint.Attachment0 :: Attachment
			table.insert(jointedAt, attachment0.WorldPosition)
		end

		local hasTop = Vector3Utils.areClose(jointedAt[1], TOP_CORNER, EPSILON)
			or Vector3Utils.areClose(jointedAt[2], TOP_CORNER, EPSILON)
		local hasBottomBack = Vector3Utils.areClose(jointedAt[1], BOTTOM_BACK_CORNER, EPSILON)
			or Vector3Utils.areClose(jointedAt[2], BOTTOM_BACK_CORNER, EPSILON)

		expect(hasTop).toBe(true)
		expect(hasBottomBack).toBe(true)

		controller:Destroy()
	end)

	it("leaves wedges that do not meet unjointed", function()
		local controller = setup()
		local model = controller.newSeparatedPair()

		local joints = FabricBallSocketUtils.create(model)

		expect(#joints).toBe(0)
		expect(#controller.getDescendantsOfClass(model, "NoCollisionConstraint")).toBe(0)

		controller:Destroy()
	end)

	it("creates a single NoCollisionConstraint between a pair of jointed wedges", function()
		local controller = setup()
		local model, first, second = controller.newQuad()

		FabricBallSocketUtils.create(model)

		local noCollisions = controller.getDescendantsOfClass(model, "NoCollisionConstraint")
		expect(#noCollisions).toBe(1)

		local noCollision = noCollisions[1] :: NoCollisionConstraint
		local parts = { noCollision.Part0, noCollision.Part1 }
		expect(table.find(parts, first) ~= nil).toBe(true)
		expect(table.find(parts, second) ~= nil).toBe(true)

		controller:Destroy()
	end)

	it("never puts a NoCollisionConstraint between a wedge and itself", function()
		local controller = setup()
		local model = controller.newQuad()

		FabricBallSocketUtils.create(model)

		for _, instance in controller.getDescendantsOfClass(model, "NoCollisionConstraint") do
			local noCollision = instance :: NoCollisionConstraint
			expect(noCollision.Part0 ~= noCollision.Part1).toBe(true)
		end

		controller:Destroy()
	end)

	it("gives every joint limits so the fabric holds its shape", function()
		local controller = setup()
		local model = controller.newQuad()

		local joints = FabricBallSocketUtils.create(model)

		for _, joint in joints do
			expect(joint.LimitsEnabled).toBe(true)
			expect(joint.UpperAngle).toBe(165)
			expect(joint.MaxFrictionTorque).toBe(0.5)
			expect(joint.Restitution).toBe(0)
		end

		controller:Destroy()
	end)

	it("orients every corner the same way regardless of how its wedge is turned", function()
		local controller = setup()
		local model = controller.newQuad()

		FabricBallSocketUtils.create(model)

		local attachments = controller.getDescendantsOfClass(model, "Attachment")
		expect(#attachments).toBe(6)

		local firstCFrame = (attachments[1] :: Attachment).WorldCFrame
		for _, instance in attachments do
			local attachment = instance :: Attachment
			expect(controller.isSameRotation(firstCFrame, attachment.WorldCFrame)).toBe(true)
		end

		controller:Destroy()
	end)

	it("unanchors the wedges it rigs", function()
		local controller = setup()
		local model, first, second = controller.newQuad()

		FabricBallSocketUtils.create(model)

		expect(first.Anchored).toBe(false)
		expect(second.Anchored).toBe(false)

		controller:Destroy()
	end)

	it("rigs wedges nested below the adornee", function()
		local controller = setup()
		local model = controller.newModel()

		local folder = controller.newFolder()
		folder.Parent = model

		local first = controller.newWedge(CFrame.new())
		first.Parent = folder

		local second = controller.newWedge(CFrame.new(0, 0, -4))
		second.Parent = folder

		local joints = FabricBallSocketUtils.create(model)

		expect(#joints).toBe(1)

		controller:Destroy()
	end)

	it("leaves parts that are not wedges alone", function()
		local controller = setup()
		local model, first = controller.newQuad()

		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = WEDGE_SIZE
		part.CFrame = CFrame.new()
		part.Parent = model

		local joints = FabricBallSocketUtils.create(model)

		expect(#joints).toBe(2)
		expect(part.Anchored).toBe(true)
		expect(#controller.getDescendantsOfClass(part, "Attachment")).toBe(0)
		expect(#controller.getDescendantsOfClass(first, "Attachment")).toBe(3)

		controller:Destroy()
	end)

	it("does nothing for an adornee with no bounding box", function()
		local controller = setup()
		local folder = controller.newFolder()

		local joints = FabricBallSocketUtils.create(folder)

		expect(#joints).toBe(0)

		controller:Destroy()
	end)
end)
