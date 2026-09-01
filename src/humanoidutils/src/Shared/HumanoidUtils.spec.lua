--!strict
--[[
	@class HumanoidUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HumanoidUtils = require("HumanoidUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newHumanoid = function(): Humanoid
			return maid:Add(Instance.new("Humanoid"))
		end,
		newRig = function(): (Model, Humanoid)
			local rig = maid:Add(Instance.new("Model"))
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = rig
			return rig, humanoid
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("HumanoidUtils.getHumanoid", function()
	it("finds the humanoid from a limb", function()
		local controller = setup()
		local rig, humanoid = controller.newRig()

		local limb = Instance.new("Part")
		limb.Parent = rig

		expect(HumanoidUtils.getHumanoid(limb)).toBe(humanoid)

		controller:Destroy()
	end)

	it("finds the humanoid from a nested descendant", function()
		local controller = setup()
		local rig, humanoid = controller.newRig()

		local accessory = Instance.new("Model")
		accessory.Parent = rig

		local handle = Instance.new("Part")
		handle.Parent = accessory

		expect(HumanoidUtils.getHumanoid(handle)).toBe(humanoid)

		controller:Destroy()
	end)

	it("returns nil outside of a humanoid model", function()
		local controller = setup()

		local part = Instance.new("Part")

		expect(HumanoidUtils.getHumanoid(part)).toBeNil()

		controller:Destroy()
	end)
end)

describe("HumanoidUtils.isHumanoidStateEnabled", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(HumanoidUtils :: any).isHumanoidStateEnabled(nil, Enum.HumanoidStateType.Jumping)
		end).toThrow("No humanoid")

		controller:Destroy()
	end)

	it("errors without a state type", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(function()
			(HumanoidUtils :: any).isHumanoidStateEnabled(humanoid, nil)
		end).toThrow("No stateType")

		controller:Destroy()
	end)

	it("reads the enabled state per state type", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		expect(HumanoidUtils.isHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping)).toBe(false)
		expect(HumanoidUtils.isHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Climbing)).toBe(true)

		controller:Destroy()
	end)
end)

describe("HumanoidUtils.isJumpEnabled", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(HumanoidUtils :: any).isJumpEnabled(nil)
		end).toThrow("No humanoid")

		controller:Destroy()
	end)

	it("is enabled for a default humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(HumanoidUtils.isJumpEnabled(humanoid)).toBe(true)

		controller:Destroy()
	end)

	it("is disabled while the jumping state is disabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		expect(HumanoidUtils.isJumpEnabled(humanoid)).toBe(false)

		controller:Destroy()
	end)

	it("reads jump power while UseJumpPower is true", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		humanoid.UseJumpPower = true
		humanoid.JumpHeight = 7
		humanoid.JumpPower = 0

		expect(HumanoidUtils.isJumpEnabled(humanoid)).toBe(false)

		humanoid.JumpPower = 50
		expect(HumanoidUtils.isJumpEnabled(humanoid)).toBe(true)

		controller:Destroy()
	end)

	it("reads jump height while UseJumpPower is false", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		humanoid.UseJumpPower = false
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 0

		expect(HumanoidUtils.isJumpEnabled(humanoid)).toBe(false)

		humanoid.JumpHeight = 7
		expect(HumanoidUtils.isJumpEnabled(humanoid)).toBe(true)

		controller:Destroy()
	end)
end)

describe("HumanoidUtils.forceUnseatHumanoid", function()
	it("leaves an unseated humanoid unseated", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		HumanoidUtils.forceUnseatHumanoid(humanoid)

		expect(humanoid.Sit).toBe(false)

		controller:Destroy()
	end)
end)
