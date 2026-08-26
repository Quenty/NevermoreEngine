--!strict
--[[
	@class RxHumanoidUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local RxHumanoidUtils = require("RxHumanoidUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local controller = {
		newHumanoid = function(): Humanoid
			return maid:Add(Instance.new("Humanoid"))
		end,
		record = function(observable: any): { any }
			local values = {}
			maid:GiveTask(observable:Subscribe(function(value)
				table.insert(values, value)
			end))
			return values
		end,
		recordUntilStopped = function(observable: any): ({ any }, () -> ())
			local values = {}
			local subscription = maid:Add(observable:Subscribe(function(value)
				table.insert(values, value)
			end))
			return values, function()
				subscription:Destroy()
			end
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("RxHumanoidUtils.observeRunningSpeed", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(RxHumanoidUtils :: any).observeRunningSpeed(nil)
		end).toThrow("No humanoid")

		controller.destroy()
	end)

	-- Cloud runs never step the humanoid state machine, so Running/Jumping/Seated never fire and only
	-- the initial emission is observable here.
	it("emits a stopped speed on subscribe", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local speeds = controller.record(RxHumanoidUtils.observeRunningSpeed(humanoid))

		expect(speeds).toEqual({ 0 })

		controller.destroy()
	end)
end)

describe("RxHumanoidUtils.observeHumanoidStateType", function()
	it("emits the current state type on subscribe", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local stateTypes = controller.record(RxHumanoidUtils.observeHumanoidStateType(humanoid))

		expect(stateTypes).toEqual({ humanoid:GetState() })

		controller.destroy()
	end)
end)

describe("RxHumanoidUtils.observeHumanoidStateEnabled", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(RxHumanoidUtils :: any).observeHumanoidStateEnabled(nil, Enum.HumanoidStateType.Jumping)
		end).toThrow("No humanoid")

		controller.destroy()
	end)

	it("errors without a state type", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		expect(function()
			(RxHumanoidUtils :: any).observeHumanoidStateEnabled(humanoid, nil)
		end).toThrow("No stateType")

		controller.destroy()
	end)

	it("emits the current enabled state on subscribe", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled =
			controller.record(RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping))

		expect(enabled).toEqual({ true })

		controller.destroy()
	end)

	it("emits when the state is disabled and re-enabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled =
			controller.record(RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

		expect(enabled).toEqual({ true, false, true })

		controller.destroy()
	end)

	it("only emits distinct values", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled =
			controller.record(RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		expect(enabled).toEqual({ true, false })

		controller.destroy()
	end)

	it("ignores other state types", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled =
			controller.record(RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

		expect(enabled).toEqual({ true })

		controller.destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled, stop = controller.recordUntilStopped(
			RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping)
		)

		stop()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		expect(enabled).toEqual({ true })

		controller.destroy()
	end)
end)

describe("RxHumanoidUtils.observeJumpEnabled", function()
	it("errors without a humanoid", function()
		local controller = setup()

		expect(function()
			(RxHumanoidUtils :: any).observeJumpEnabled(nil)
		end).toThrow("No humanoid")

		controller.destroy()
	end)

	it("is enabled for a default humanoid", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		expect(enabled).toEqual({ true })

		controller.destroy()
	end)

	it("is disabled while the jumping state is disabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

		expect(enabled).toEqual({ true, false, true })

		controller.destroy()
	end)

	it("reads jump power while UseJumpPower is true", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = true
		humanoid.JumpHeight = 0

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.JumpPower = 0
		humanoid.JumpPower = 50

		expect(enabled).toEqual({ true, false, true })

		controller.destroy()
	end)

	it("reads jump height while UseJumpPower is false", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = false
		humanoid.JumpPower = 0

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.JumpHeight = 0
		humanoid.JumpHeight = 7

		expect(enabled).toEqual({ true, false, true })

		controller.destroy()
	end)

	it("switches which jump strength it reads with UseJumpPower", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 0

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.UseJumpPower = false
		humanoid.UseJumpPower = true

		expect(enabled).toEqual({ true, false, true })

		controller.destroy()
	end)

	it("ignores the unused jump strength", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid.JumpHeight = 0
		humanoid.JumpHeight = 12

		expect(enabled).toEqual({ true })

		controller.destroy()
	end)

	it("stays disabled while both the state and the jump power are disabled", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		local enabled = controller.record(RxHumanoidUtils.observeJumpEnabled(humanoid))

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = 50

		expect(enabled).toEqual({ false, true })

		controller.destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()
		local humanoid = controller.newHumanoid()

		local enabled, stop = controller.recordUntilStopped(RxHumanoidUtils.observeJumpEnabled(humanoid))

		stop()
		humanoid.JumpPower = 0

		expect(enabled).toEqual({ true })

		controller.destroy()
	end)
end)
