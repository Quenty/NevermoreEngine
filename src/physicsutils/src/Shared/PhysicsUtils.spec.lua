--!strict
--[[
	@class PhysicsUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PhysicsUtils = require("PhysicsUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type PartOptions = {
	size: Vector3?,
	position: Vector3?,
	density: number?,
	canCollide: boolean?,
}

type Controller = {
	newPart: (options: PartOptions?) -> BasePart,
	weld: (part0: BasePart, part1: BasePart) -> WeldConstraint,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local folder = Instance.new("Folder")
	folder.Name = "PhysicsUtilsSpec"
	folder.Parent = Workspace
	maid:GiveTask(folder)

	local self = {} :: Controller

	function self.newPart(options: PartOptions?): BasePart
		local resolved: PartOptions = options or {}

		local part = Instance.new("Part")
		part.Anchored = false
		part.Size = resolved.size or Vector3.new(2, 2, 2)
		part.Position = resolved.position or Vector3.zero
		part.CanCollide = if resolved.canCollide ~= nil then resolved.canCollide else true
		part.CustomPhysicalProperties = PhysicalProperties.new(resolved.density or 1, 0, 0)
		part.Parent = folder

		return part
	end

	function self.weld(part0: BasePart, part1: BasePart): WeldConstraint
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part0
		weld.Part1 = part1
		weld.Parent = part0

		return weld
	end

	function self.Destroy(_self: Controller)
		maid:DoCleaning()
	end

	return self
end

describe("PhysicsUtils.getMass", function()
	it("sums the mass of every part", function()
		local controller = setup()
		local partA = controller.newPart({ size = Vector3.new(2, 2, 2), density = 1 })
		local partB = controller.newPart({ size = Vector3.new(1, 2, 3), density = 2 })

		expect(PhysicsUtils.getMass({ partA, partB })).toBeCloseTo(8 + 12, 3)

		controller:Destroy()
	end)

	it("is zero for no parts", function()
		expect(PhysicsUtils.getMass({})).toBe(0)
	end)
end)

describe("PhysicsUtils.getConnectedParts", function()
	it("includes the part itself when nothing is connected", function()
		local controller = setup()
		local part = controller.newPart()

		expect(PhysicsUtils.getConnectedParts(part)).toEqual({ part })

		controller:Destroy()
	end)

	it("includes welded parts and the part itself", function()
		local controller = setup()
		local partA = controller.newPart({ position = Vector3.new(0, 0, 0) })
		local partB = controller.newPart({ position = Vector3.new(2, 0, 0) })
		local partC = controller.newPart({ position = Vector3.new(4, 0, 0) })
		controller.weld(partA, partB)
		controller.weld(partB, partC)

		local parts = PhysicsUtils.getConnectedParts(partA)

		expect(#parts).toBe(3)
		expect(parts).toContain(partA)
		expect(parts).toContain(partB)
		expect(parts).toContain(partC)

		controller:Destroy()
	end)
end)

describe("PhysicsUtils.estimateBuoyancyContribution", function()
	it("is neutral when a colliding part matches water density", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 3, 4), density = PhysicsUtils.WATER_DENSITY })

		local float, mass, volume = PhysicsUtils.estimateBuoyancyContribution({ part })

		expect(float).toBeCloseTo(0, 3)
		expect(mass).toBeCloseTo(24, 3)
		expect(volume).toBeCloseTo(24, 3)

		controller:Destroy()
	end)

	it("sinks when a colliding part is denser than water", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 3, 4), density = 2 })

		local float, mass, volume = PhysicsUtils.estimateBuoyancyContribution({ part })

		expect(float).toBeCloseTo(-24 * Workspace.Gravity, 3)
		expect(mass).toBeCloseTo(48, 3)
		expect(volume).toBeCloseTo(24, 3)

		controller:Destroy()
	end)

	it("floats when a colliding part is lighter than water", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 3, 4), density = 0.5 })

		local float = PhysicsUtils.estimateBuoyancyContribution({ part })

		expect(float).toBeCloseTo(12 * Workspace.Gravity, 3)

		controller:Destroy()
	end)

	it("counts mass but not volume for non-colliding parts", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 3, 4), density = 1, canCollide = false })

		local float, mass, volume = PhysicsUtils.estimateBuoyancyContribution({ part })

		expect(float).toBeCloseTo(-24 * Workspace.Gravity, 3)
		expect(mass).toBeCloseTo(24, 3)
		expect(volume).toBe(0)

		controller:Destroy()
	end)

	it("accumulates across parts", function()
		local controller = setup()
		local floating = controller.newPart({ size = Vector3.new(2, 2, 2), density = 0.5 })
		local sinking = controller.newPart({ size = Vector3.new(1, 1, 1), density = 3, canCollide = false })

		local float, mass, volume = PhysicsUtils.estimateBuoyancyContribution({ floating, sinking })

		expect(float).toBeCloseTo((8 - 4 - 3) * Workspace.Gravity, 3)
		expect(mass).toBeCloseTo(4 + 3, 3)
		expect(volume).toBeCloseTo(8, 3)

		controller:Destroy()
	end)

	it("returns zeros for no parts", function()
		local float, mass, volume = PhysicsUtils.estimateBuoyancyContribution({})

		expect(float).toBe(0)
		expect(mass).toBe(0)
		expect(volume).toBe(0)
	end)
end)

describe("PhysicsUtils.getCenterOfMass", function()
	it("returns the midpoint for equal masses", function()
		local controller = setup()
		local partA = controller.newPart({ position = Vector3.new(0, 0, 0) })
		local partB = controller.newPart({ position = Vector3.new(10, 0, 0) })

		local center, mass = PhysicsUtils.getCenterOfMass({ partA, partB })

		expect(center.X).toBeCloseTo(5, 3)
		expect(center.Y).toBeCloseTo(0, 3)
		expect(center.Z).toBeCloseTo(0, 3)
		expect(mass).toBeCloseTo(16, 3)

		controller:Destroy()
	end)

	it("weights the center towards the heavier part", function()
		local controller = setup()
		local light = controller.newPart({ position = Vector3.new(0, 0, 0), density = 1 })
		local heavy = controller.newPart({ position = Vector3.new(0, 12, 0), density = 3 })

		local center = PhysicsUtils.getCenterOfMass({ light, heavy })

		expect(center.Y).toBeCloseTo(9, 3)

		controller:Destroy()
	end)
end)

describe("PhysicsUtils.momentOfInertia", function()
	it("uses only the cuboid term when the origin is the part position", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 4, 6), position = Vector3.new(1, 2, 3) })
		local mass = part:GetMass()

		local inertia = PhysicsUtils.momentOfInertia(part, Vector3.yAxis, part.Position)

		expect(inertia).toBeCloseTo((2 ^ 2 + 6 ^ 2) * mass / 12, 3)

		controller:Destroy()
	end)

	it("adds the parallel axis term for an offset origin", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 4, 6), position = Vector3.new(3, 0, 0) })
		local mass = part:GetMass()

		local inertia = PhysicsUtils.momentOfInertia(part, Vector3.yAxis, Vector3.zero)

		expect(inertia).toBeCloseTo(mass * 9 + (2 ^ 2 + 6 ^ 2) * mass / 12, 3)

		controller:Destroy()
	end)

	it("ignores offsets along the axis", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 4, 6), position = Vector3.new(0, 5, 0) })
		local mass = part:GetMass()

		local inertia = PhysicsUtils.momentOfInertia(part, Vector3.yAxis, Vector3.zero)

		expect(inertia).toBeCloseTo((2 ^ 2 + 6 ^ 2) * mass / 12, 3)

		controller:Destroy()
	end)
end)

describe("PhysicsUtils.bodyMomentOfInertia", function()
	it("sums the moment of inertia of each part", function()
		local controller = setup()
		local partA = controller.newPart({ size = Vector3.new(2, 4, 6), position = Vector3.new(3, 0, 0) })
		local partB = controller.newPart({ size = Vector3.new(1, 1, 1), position = Vector3.new(-2, 0, 0) })

		local expected = PhysicsUtils.momentOfInertia(partA, Vector3.yAxis, Vector3.zero)
			+ PhysicsUtils.momentOfInertia(partB, Vector3.yAxis, Vector3.zero)

		expect(PhysicsUtils.bodyMomentOfInertia({ partA, partB }, Vector3.yAxis, Vector3.zero)).toBeCloseTo(expected, 3)

		controller:Destroy()
	end)
end)

describe("PhysicsUtils.applyForce", function()
	it("adds linear velocity without rotation when applied at the center of mass", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 2, 2), density = 1 })

		PhysicsUtils.applyForce(part, Vector3.new(16, 0, 0), part.Position)

		expect(part.AssemblyLinearVelocity.X).toBeCloseTo(2, 3)
		expect(part.AssemblyLinearVelocity.Y).toBeCloseTo(0, 3)
		expect(part.AssemblyLinearVelocity.Z).toBeCloseTo(0, 3)
		expect(part.AssemblyAngularVelocity.Magnitude).toBeCloseTo(0, 3)

		controller:Destroy()
	end)

	it("adds angular velocity when applied off center", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 2, 2), density = 1 })

		PhysicsUtils.applyForce(part, Vector3.new(0, 0, 8), part.Position + Vector3.new(1, 0, 0))

		expect(part.AssemblyLinearVelocity.Z).toBeCloseTo(1, 3)
		expect(part.AssemblyAngularVelocity.Magnitude).toBeGreaterThan(0)

		controller:Destroy()
	end)
end)

describe("PhysicsUtils.acceleratePart", function()
	it("applies equal and opposite forces to the part and emitter", function()
		local controller = setup()
		local part = controller.newPart({ size = Vector3.new(2, 2, 2), density = 1, position = Vector3.zero })
		local emitter = controller.newPart({ size = Vector3.new(4, 4, 4), density = 1, position = Vector3.zero })

		PhysicsUtils.acceleratePart(part, emitter, Vector3.new(0, 5, 0))

		expect(part.AssemblyLinearVelocity.Y).toBeCloseTo(5, 3)
		expect(emitter.AssemblyLinearVelocity.Y).toBeCloseTo(-5 * 8 / 64, 3)

		controller:Destroy()
	end)
end)
