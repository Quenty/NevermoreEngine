--!strict
--[[
	@class TouchButtonScoredActionPicker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local ScoredAction = require("ScoredAction")
local TouchButtonScoredActionPicker = require("TouchButtonScoredActionPicker")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newPicker: () -> TouchButtonScoredActionPicker.TouchButtonScoredActionPicker,
	newLoosePicker: () -> TouchButtonScoredActionPicker.TouchButtonScoredActionPicker,
	newAction: (number) -> ScoredAction.ScoredAction,
	newLooseAction: (number) -> ScoredAction.ScoredAction,
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local function makeAction(score: number): ScoredAction.ScoredAction
		local action: ScoredAction.ScoredAction = ScoredAction.new()
		action:SetScore(score)
		return action
	end

	local controller: Controller = {
		newPicker = function()
			return maid:Add(TouchButtonScoredActionPicker.new()) :: any
		end,

		newLoosePicker = function()
			return TouchButtonScoredActionPicker.new()
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

describe("TouchButtonScoredActionPicker.Update", function()
	it("prefers every action at once", function()
		local controller = setup()
		local picker = controller.newPicker()

		local first = controller.newAction(1)
		local second = controller.newAction(2)
		picker:AddAction(first)
		picker:AddAction(second)
		picker:Update()

		-- Unlike keys, there are as many touch buttons as we want, so a lower score is not a loss.
		expect(first:IsPreferred()).toBe(true)
		expect(second:IsPreferred()).toBe(true)

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

	it("does not prefer an action that is already disabled", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		action:SetIsEnabled(false)
		picker:AddAction(action)

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("drops the preference when the action is disabled", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)
		expect(action:IsPreferred()).toBe(true)

		action:SetIsEnabled(false)
		picker:Update()

		expect(action:IsPreferred()).toBe(false)

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

	it("leaves the other actions alone when one is disabled", function()
		local controller = setup()
		local picker = controller.newPicker()

		local disabled = controller.newAction(1)
		local enabled = controller.newAction(1)
		picker:AddAction(disabled)
		picker:AddAction(enabled)

		disabled:SetIsEnabled(false)
		picker:Update()

		expect(disabled:IsPreferred()).toBe(false)
		expect(enabled:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("drops the preference when the action is removed", function()
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

	it("prefers an action that gained a score", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(-math.huge)
		picker:AddAction(action)

		action:SetScore(1)
		picker:Update()

		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("holds a single preference across repeated updates", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)

		picker:Update()
		picker:Update()
		picker:RemoveAction(action)

		expect(action:IsPreferred()).toBe(false)

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

describe("TouchButtonScoredActionPicker.AddAction", function()
	it("ignores a repeated add of the same action", function()
		local controller = setup()
		local picker = controller.newPicker()

		local action = controller.newAction(1)
		picker:AddAction(action)
		picker:AddAction(action)
		picker:RemoveAction(action)

		expect(action:IsPreferred()).toBe(false)
		expect(picker:HasActions()).toBe(false)

		controller.destroy()
	end)
end)

describe("TouchButtonScoredActionPicker.RemoveAction", function()
	it("leaves the other actions preferred", function()
		local controller = setup()
		local picker = controller.newPicker()

		local removed = controller.newAction(1)
		local remaining = controller.newAction(1)
		picker:AddAction(removed)
		picker:AddAction(remaining)

		picker:RemoveAction(removed)

		expect(removed:IsPreferred()).toBe(false)
		expect(remaining:IsPreferred()).toBe(true)

		controller.destroy()
	end)
end)

describe("TouchButtonScoredActionPicker.HasActions", function()
	it("is false for a new picker", function()
		local controller = setup()
		local picker = controller.newPicker()

		expect(picker:HasActions()).toBe(false)

		controller.destroy()
	end)
end)

describe("TouchButtonScoredActionPicker.Destroy", function()
	it("drops the preferences it was holding", function()
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
