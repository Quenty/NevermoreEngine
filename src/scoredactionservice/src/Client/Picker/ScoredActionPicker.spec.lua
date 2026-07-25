--!strict
--[[
	@class ScoredActionPicker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ScoredAction = require("ScoredAction")
local ScoredActionPicker = require("ScoredActionPicker")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local function makeAction(score: number): ScoredAction.ScoredAction
		local action: ScoredAction.ScoredAction = ScoredAction.new()
		action:SetScore(score)
		return action
	end

	local controller = {
		newPicker = function()
			return maid:Add(ScoredActionPicker.new()) :: any
		end,

		newLoosePicker = function()
			return ScoredActionPicker.new()
		end,

		newAction = function(score: number)
			return maid:Add(makeAction(score)) :: any
		end,

		newLooseAction = makeAction,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("ScoredActionPicker.Update", function()
	it("prefers the highest scoring action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local low = controller.newAction(1)
		local high = controller.newAction(2)
		picker:AddAction(low)
		picker:AddAction(high)
		picker:Update()

		expect(high:IsPreferred()).toBe(true)
		expect(low:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("never prefers an action scored at -math.huge", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(-math.huge)
		picker:AddAction(action)
		picker:Update()

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("drops the preference when the only action is disabled", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)
		expect(action:IsPreferred()).toBe(true)

		-- The action stays in the set while disabled, so nothing else can take the preference off it.
		-- Left preferred, a control told to disable itself stays bound and keeps its hint on screen.
		action:SetIsEnabled(false)
		picker:Update()

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("hands the preference to the best still-enabled action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local low = controller.newAction(1)
		local high = controller.newAction(2)
		picker:AddAction(low)
		picker:AddAction(high)
		picker:Update()

		high:SetIsEnabled(false)
		picker:Update()

		expect(high:IsPreferred()).toBe(false)
		expect(low:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("gives the preference back when the action is re-enabled", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)

		action:SetIsEnabled(false)
		picker:Update()
		expect(action:IsPreferred()).toBe(false)

		action:SetIsEnabled(true)
		picker:Update()
		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("drops the preference when the preferred action is removed", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)
		expect(action:IsPreferred()).toBe(true)

		picker:RemoveAction(action)

		expect(action:IsPreferred()).toBe(false)
		expect(picker:HasActions()).toBe(false)

		controller.destroy()
	end)

	it("breaks score ties in favor of the older action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local older = controller.newAction(1)
		local newer = controller.newAction(1)
		picker:AddAction(newer)
		picker:AddAction(older)
		picker:Update()

		expect(older:IsPreferred()).toBe(true)
		expect(newer:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("skips past unscored actions to reach a scored one", function()
		local controller = setup()
		local picker = controller.newPicker()

		local unscored = controller.newAction(-math.huge)
		local scored = controller.newAction(-1000)
		picker:AddAction(unscored)
		picker:AddAction(scored)
		picker:Update()

		expect(scored:IsPreferred()).toBe(true)
		expect(unscored:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("moves the preference when a score change reorders the actions", function()
		local controller = setup()
		local picker = controller.newPicker()

		local first = controller.newAction(2)
		local second = controller.newAction(1)
		picker:AddAction(first)
		picker:AddAction(second)
		picker:Update()
		expect(first:IsPreferred()).toBe(true)

		second:SetScore(3)
		picker:Update()

		expect(first:IsPreferred()).toBe(false)
		expect(second:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("tolerates an action destroyed without being removed", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newLooseAction(1)
		picker:AddAction(action)
		action:Destroy()

		expect(function()
			picker:Update()
		end).never.toThrow()

		controller.destroy()
	end)
end)

describe("ScoredActionPicker.AddAction", function()
	it("prefers the action without an explicit update", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)

		expect(action:IsPreferred()).toBe(true)
		expect(picker:HasActions()).toBe(true)

		controller.destroy()
	end)

	it("re-evaluates when an action's enabled state changes", function()
		local controller = setup()
		local picker = controller.newPicker()

		local low = controller.newAction(1)
		local high = controller.newAction(2)
		picker:AddAction(low)
		picker:AddAction(high)

		high:SetIsEnabled(false)

		expect(high:IsPreferred()).toBe(false)
		expect(low:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("ignores a repeated add of the same action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)
		picker:AddAction(action)
		picker:RemoveAction(action)

		expect(picker:HasActions()).toBe(false)

		controller.destroy()
	end)

	it("throws on a non-table action", function()
		local controller = setup()
		local picker = controller.newPicker()

		expect(function()
			(picker :: any):AddAction("action")
		end).toThrow()

		controller.destroy()
	end)
end)

describe("ScoredActionPicker.RemoveAction", function()
	it("hands the preference to the next best action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local low = controller.newAction(1)
		local high = controller.newAction(2)
		picker:AddAction(low)
		picker:AddAction(high)

		picker:RemoveAction(high)

		expect(low:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("stops tracking the enabled state of a removed action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local removed = controller.newAction(2)
		local remaining = controller.newAction(1)
		picker:AddAction(removed)
		picker:AddAction(remaining)
		picker:RemoveAction(removed)

		removed:SetIsEnabled(false)

		expect(remaining:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("ignores an action that was never added", function()
		local controller = setup()
		local picker = controller.newPicker()
		local action = controller.newAction(1)

		expect(function()
			picker:RemoveAction(action)
		end).never.toThrow()

		controller.destroy()
	end)

	it("throws on a non-table action", function()
		local controller = setup()
		local picker = controller.newPicker()

		expect(function()
			(picker :: any):RemoveAction("action")
		end).toThrow()

		controller.destroy()
	end)
end)

describe("ScoredActionPicker.Destroy", function()
	it("drops the preference it was holding", function()
		local controller = setup()
		local picker = controller.newLoosePicker()

		local action = controller.newAction(1)
		picker:AddAction(action)
		expect(action:IsPreferred()).toBe(true)

		picker:Destroy()

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)
end)
