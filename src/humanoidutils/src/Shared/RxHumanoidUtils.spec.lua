--!strict
--[[
	@class RxHumanoidUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local RxHumanoidUtils = require("RxHumanoidUtils")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newHumanoid = function(): Humanoid
			return maid:Add(Instance.new("Humanoid"))
		end,
		maid = maid,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxHumanoidUtils.observeRunningSpeed", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(RxHumanoidUtils :: any).observeRunningSpeed(nil)
		end).toThrow("No humanoid")

		controller:Destroy()
	end)

	-- Cloud runs never step the humanoid state machine, so Running/Jumping/Seated never fire and only
	-- the initial emission is observable here.
	it("emits a stopped speed on subscribe", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local speeds = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeRunningSpeed(humanoid))

		expect(speeds).toEqual({ 0 })

		controller:Destroy()
	end)
end)

describe("RxHumanoidUtils.observeHumanoidStateType", function()
	it("emits the current state type on subscribe", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local stateTypes = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeHumanoidStateType(humanoid))

		expect(stateTypes).toEqual({ humanoid:GetState() })

		controller:Destroy()
	end)
end)

describe("RxHumanoidUtils.observeHumanoidStateEnabled", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(RxHumanoidUtils :: any).observeHumanoidStateEnabled(nil, Enum.HumanoidStateType.Jumping)
		end).toThrow("No humanoid")

		controller:Destroy()
	end)

	it("errors without a state type", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(function()
			(RxHumanoidUtils :: any).observeHumanoidStateEnabled(humanoid, nil)
		end).toThrow("No stateType")

		controller:Destroy()
	end)

	it("emits the current enabled state on subscribe", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = RxTestUtils.collectList(
			controller.maid,
			RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping)
		)

		expect(enabled).toEqual({ true })

		controller:Destroy()
	end)

	it("emits when the state is disabled and re-enabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = RxTestUtils.collectList(
			controller.maid,
			RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping)
		)

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

		expect(enabled).toEqual({ true, false, true })

		controller:Destroy()
	end)

	it("only emits distinct values", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = RxTestUtils.collectList(
			controller.maid,
			RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping)
		)

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		expect(enabled).toEqual({ true, false })

		controller:Destroy()
	end)

	it("ignores other state types", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = RxTestUtils.collectList(
			controller.maid,
			RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping)
		)

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

		expect(enabled).toEqual({ true })

		controller:Destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = controller.maid:Add(
			ObservableSpy.new(RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping))
		)

		enabled:Destroy()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		expect(enabled.Values).toEqual({ true })

		controller:Destroy()
	end)
end)

describe("RxHumanoidUtils.observeJumpEnabled", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(RxHumanoidUtils :: any).observeJumpEnabled(nil)
		end).toThrow("No humanoid")

		controller:Destroy()
	end)

	it("is enabled for a default humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		expect(enabled).toEqual({ true })

		controller:Destroy()
	end)

	it("is disabled while the jumping state is disabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

		expect(enabled).toEqual({ true, false, true })

		controller:Destroy()
	end)

	it("reads jump power while UseJumpPower is true", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = true
		humanoid.JumpHeight = 0

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.JumpPower = 0
		humanoid.JumpPower = 50

		expect(enabled).toEqual({ true, false, true })

		controller:Destroy()
	end)

	it("reads jump height while UseJumpPower is false", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = false
		humanoid.JumpPower = 0

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.JumpHeight = 0
		humanoid.JumpHeight = 7

		expect(enabled).toEqual({ true, false, true })

		controller:Destroy()
	end)

	it("switches which jump strength it reads with UseJumpPower", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 0

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.UseJumpPower = false
		humanoid.UseJumpPower = true

		expect(enabled).toEqual({ true, false, true })

		controller:Destroy()
	end)

	it("ignores the unused jump strength", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.JumpHeight = 0
		humanoid.JumpHeight = 12

		expect(enabled).toEqual({ true })

		controller:Destroy()
	end)

	it("stays disabled while both the state and the jump power are disabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		local enabled = RxTestUtils.collectList(controller.maid, RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = 50

		expect(enabled).toEqual({ false, true })

		controller:Destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = controller.maid:Add(ObservableSpy.new(RxHumanoidUtils.observeJumpEnabled(humanoid)))

		enabled:Destroy()
		humanoid.JumpPower = 0

		expect(enabled.Values).toEqual({ true })

		controller:Destroy()
	end)
end)
