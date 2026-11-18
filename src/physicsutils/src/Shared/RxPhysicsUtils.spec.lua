--!strict
--[[
	@class RxPhysicsUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local RxPhysicsUtils = require("RxPhysicsUtils")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	newPart: (density: number?) -> BasePart,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local folder = maid:Add(Instance.new("Folder"))
	folder.Name = "RxPhysicsUtilsSpec"
	folder.Parent = Workspace

	local controller: Controller = {
		maid = maid,
		newPart = function(density)
			local part = Instance.new("Part")
			part.Anchored = true
			part.Size = Vector3.new(2, 2, 2)
			if density then
				part.CustomPhysicalProperties = PhysicalProperties.new(density, 0, 0)
			end
			part.Parent = folder

			return part
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxPhysicsUtils.observePartMass", function()
	it("emits the current mass on subscribe", function()
		local controller = setup()
		local part = controller.newPart(1)

		local masses = RxTestUtils.collectList(controller.maid, RxPhysicsUtils.observePartMass(part))

		expect(masses).toEqual({ 8 })
	end)

	it("emits when the size changes", function()
		local controller = setup()
		local part = controller.newPart(1)
		local masses = RxTestUtils.collectList(controller.maid, RxPhysicsUtils.observePartMass(part))

		part.Size = Vector3.new(1, 2, 3)

		expect(masses).toEqual({ 8, 6 })
	end)

	it("emits when the custom physical properties change", function()
		local controller = setup()
		local part = controller.newPart(1)
		local masses = RxTestUtils.collectList(controller.maid, RxPhysicsUtils.observePartMass(part))

		part.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0)

		expect(masses).toEqual({ 8, 16 })
	end)

	it("emits when the material changes the density", function()
		local controller = setup()
		local part = controller.newPart()
		part.Material = Enum.Material.Plastic
		local masses = RxTestUtils.collectList(controller.maid, RxPhysicsUtils.observePartMass(part))
		local plasticMass = part:GetMass()

		part.Material = Enum.Material.Metal

		local metalMass = part:GetMass()
		expect(metalMass).never.toBeCloseTo(plasticMass, 3)
		expect(masses).toEqual({ plasticMass, metalMass })
	end)

	it("does not emit when a watched property changes but the mass does not", function()
		local controller = setup()
		local part = controller.newPart(1)
		local masses = RxTestUtils.collectList(controller.maid, RxPhysicsUtils.observePartMass(part))

		part.Material = Enum.Material.Metal

		expect(masses).toEqual({ 8 })
	end)

	it("stops emitting after unsubscribe", function()
		local controller = setup()
		local part = controller.newPart(1)

		local masses = controller.maid:Add(ObservableSpy.new(RxPhysicsUtils.observePartMass(part)))
		masses:Destroy()

		part.Size = Vector3.new(4, 4, 4)

		expect(masses.Values).toEqual({ 8 })
	end)

	it("errors when given a non-part", function()
		expect(function()
			RxPhysicsUtils.observePartMass(Instance.new("Folder") :: any)
		end).toThrow("Bad part")
	end)
end)
