--!strict
--[[
	@class ScoredAction.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ScoredAction = require("ScoredAction")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newAction: () -> ScoredAction.ScoredAction,
	newLooseAction: () -> ScoredAction.ScoredAction,
	newValue: (boolean) -> ValueObject.ValueObject<boolean>,
	collect: (any) -> { any },
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newAction = function()
			return maid:Add(ScoredAction.new()) :: any
		end,

		newLooseAction = function()
			return ScoredAction.new()
		end,

		newValue = function(value: boolean)
			return maid:Add(ValueObject.new(value, "boolean")) :: any
		end,

		collect = function(observable)
			local results = {}
			maid:GiveTask(observable:Subscribe(function(value)
				table.insert(results, value)
			end))
			return results
		end,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("ScoredAction.new", function()
	it("starts unscored, enabled, and unpreferred", function()
		local controller = setup()
		local action = controller.newAction()

		expect(action:GetScore()).toBe(-math.huge)
		expect(action:IsEnabled()).toBe(true)
		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)
end)

describe("ScoredAction.SetScore", function()
	it("round trips the score", function()
		local controller = setup()
		local action = controller.newAction()

		action:SetScore(5)

		expect(action:GetScore()).toBe(5)

		controller.destroy()
	end)

	it("throws on a non-number score", function()
		local controller = setup()
		local action = controller.newAction()

		expect(function()
			(action :: any):SetScore("5")
		end).toThrow()

		controller.destroy()
	end)
end)

describe("ScoredAction.SetIsEnabled", function()
	it("sets the enabled state from a boolean", function()
		local controller = setup()
		local action = controller.newAction()

		action:SetIsEnabled(false)

		expect(action:IsEnabled()).toBe(false)

		controller.destroy()
	end)

	it("tracks an observable source", function()
		local controller = setup()
		local action = controller.newAction()
		local isEnabled = controller.newValue(true)

		action:SetIsEnabled(isEnabled:Observe())
		isEnabled.Value = false

		expect(action:IsEnabled()).toBe(false)

		controller.destroy()
	end)

	it("stops tracking the observable source once unmounted", function()
		local controller = setup()
		local action = controller.newAction()
		local isEnabled = controller.newValue(true)

		local unmount = action:SetIsEnabled(isEnabled:Observe())
		unmount()
		isEnabled.Value = false

		expect(action:IsEnabled()).toBe(true)

		controller.destroy()
	end)

	it("fires EnabledChanged with the new state", function()
		local controller = setup()
		local action = controller.newAction()

		local states = controller.collect(action:ObserveIsEnabled())
		action:SetIsEnabled(false)
		action:SetIsEnabled(true)

		expect(states).toEqual({ true, false, true })

		controller.destroy()
	end)
end)

describe("ScoredAction.ObserveIsEnabled", function()
	it("emits the current state then each change", function()
		local controller = setup()
		local action = controller.newAction()

		local states = controller.collect(action:ObserveIsEnabled())
		action:SetIsEnabled(false)

		expect(states).toEqual({ true, false })

		controller.destroy()
	end)
end)

describe("ScoredAction.PushPreferred", function()
	it("is preferred while pushed", function()
		local controller = setup()
		local action = controller.newAction()

		local pop = action:PushPreferred()
		expect(action:IsPreferred()).toBe(true)

		pop()
		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("stays preferred until every push is popped", function()
		local controller = setup()
		local action = controller.newAction()

		local popFirst = action:PushPreferred()
		local popSecond = action:PushPreferred()

		popFirst()
		expect(action:IsPreferred()).toBe(true)

		popSecond()
		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("fires PreferredChanged with the new state", function()
		local controller = setup()
		local action = controller.newAction()

		local states = {}
		action.PreferredChanged:Connect(function(isPreferred)
			table.insert(states, isPreferred)
		end)

		action:PushPreferred()()

		expect(states).toEqual({ true, false })

		controller.destroy()
	end)

	it("does not require a score", function()
		local controller = setup()
		local action = controller.newAction()

		action:PushPreferred()

		expect(action:GetScore()).toBe(-math.huge)
		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)
end)

describe("ScoredAction.ObservePreferred", function()
	it("emits the current state then each change", function()
		local controller = setup()
		local action = controller.newAction()

		local states = controller.collect(action:ObservePreferred())
		action:PushPreferred()()

		expect(states).toEqual({ false, true, false })

		controller.destroy()
	end)
end)

describe("ScoredAction.Destroy", function()
	it("fires Removing", function()
		local controller = setup()
		local action = controller.newLooseAction()

		local fired = false
		action.Removing:Connect(function()
			fired = true
		end)

		action:Destroy()

		expect(fired).toBe(true)

		controller.destroy()
	end)

	it("clears the metatable so pickers can detect a stale action", function()
		local controller = setup()
		local action = controller.newLooseAction()
		action:PushPreferred()

		action:Destroy()

		expect((action :: any).Destroy).toBeNil()

		controller.destroy()
	end)
end)
