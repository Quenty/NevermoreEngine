--!strict
--[[
	@class RxPhysicsUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local RxPhysicsUtils = require("RxPhysicsUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newPart: (density: number?) -> BasePart,
	observeMass: (part: BasePart) -> { number },
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local folder = Instance.new("Folder")
	folder.Name = "RxPhysicsUtilsSpec"
	folder.Parent = Workspace
	maid:GiveTask(folder)

	local self = {} :: Controller

	function self.newPart(density: number?): BasePart
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(2, 2, 2)
		if density then
			part.CustomPhysicalProperties = PhysicalProperties.new(density, 0, 0)
		end
		part.Parent = folder

		return part
	end

	function self.observeMass(part: BasePart): { number }
		local values = {}
		maid:GiveTask(RxPhysicsUtils.observePartMass(part):Subscribe(function(mass)
			table.insert(values, mass)
		end))

		return values
	end

	function self.Destroy(_self: Controller)
		maid:DoCleaning()
	end

	return self
end

describe("RxPhysicsUtils.observePartMass", function()
	it("emits the current mass on subscribe", function()
		local controller = setup()
		local part = controller.newPart(1)

		local values = controller.observeMass(part)

		expect(values).toEqual({ 8 })

		controller:Destroy()
	end)

	it("emits when the size changes", function()
		local controller = setup()
		local part = controller.newPart(1)
		local values = controller.observeMass(part)

		part.Size = Vector3.new(1, 2, 3)
		task.wait()

		expect(values).toEqual({ 8, 6 })

		controller:Destroy()
	end)

	it("emits when the custom physical properties change", function()
		local controller = setup()
		local part = controller.newPart(1)
		local values = controller.observeMass(part)

		part.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0)
		task.wait()

		expect(values).toEqual({ 8, 16 })

		controller:Destroy()
	end)

	it("emits when the material changes the density", function()
		local controller = setup()
		local part = controller.newPart()
		part.Material = Enum.Material.Plastic
		local values = controller.observeMass(part)
		local plasticMass = part:GetMass()

		part.Material = Enum.Material.Metal
		task.wait()

		local metalMass = part:GetMass()
		expect(metalMass).never.toBeCloseTo(plasticMass, 3)
		expect(values).toEqual({ plasticMass, metalMass })

		controller:Destroy()
	end)

	it("does not emit when a watched property changes but the mass does not", function()
		local controller = setup()
		local part = controller.newPart(1)
		local values = controller.observeMass(part)

		part.Material = Enum.Material.Metal
		task.wait()

		expect(values).toEqual({ 8 })

		controller:Destroy()
	end)

	it("stops emitting after unsubscribe", function()
		local controller = setup()
		local part = controller.newPart(1)

		local values = {}
		local subscription = RxPhysicsUtils.observePartMass(part):Subscribe(function(mass)
			table.insert(values, mass)
		end)
		subscription:Destroy()

		part.Size = Vector3.new(4, 4, 4)
		task.wait()

		expect(values).toEqual({ 8 })

		controller:Destroy()
	end)

	it("errors when given a non-part", function()
		expect(function()
			RxPhysicsUtils.observePartMass(Instance.new("Folder") :: any)
		end).toThrow("Bad part")
	end)
end)
