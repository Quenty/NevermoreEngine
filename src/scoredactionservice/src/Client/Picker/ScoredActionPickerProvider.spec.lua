--!strict
--[[
	@class ScoredActionPickerProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ScoredAction = require("ScoredAction")
local ScoredActionPickerProvider = require("ScoredActionPickerProvider")
local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newProvider: () -> ScoredActionPickerProvider.ScoredActionPickerProvider,
	newLooseProvider: () -> ScoredActionPickerProvider.ScoredActionPickerProvider,
	newAction: (number) -> ScoredAction.ScoredAction,
	slot: (string) -> any,
	destroy: () -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newProvider = function()
			return maid:Add(ScoredActionPickerProvider.new()) :: any
		end,

		newLooseProvider = function()
			return ScoredActionPickerProvider.new()
		end,

		newAction = function(score: number)
			local action: ScoredAction.ScoredAction = maid:Add(ScoredAction.new()) :: any
			action:SetScore(score)
			return action
		end,

		slot = function(slotId: string)
			return SlottedTouchButtonUtils.createSlottedTouchButton(slotId)
		end,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("ScoredActionPickerProvider.GetOrCreatePicker", function()
	it("reuses the picker for an input type", function()
		local controller = setup()
		local provider = controller.newProvider()

		local first = provider:GetOrCreatePicker(Enum.KeyCode.E)
		local second = provider:GetOrCreatePicker(Enum.KeyCode.E)

		expect(second).toBe(first)

		controller.destroy()
	end)

	it("creates a separate picker per input type", function()
		local controller = setup()
		local provider = controller.newProvider()

		local keyboard = provider:GetOrCreatePicker(Enum.KeyCode.E)
		local gamepad = provider:GetOrCreatePicker(Enum.KeyCode.ButtonX)

		expect(gamepad).never.toBe(keyboard)

		controller.destroy()
	end)

	it("creates a competing picker for a key code", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker = provider:GetOrCreatePicker(Enum.KeyCode.E)

		expect((picker :: any).ClassName).toBe("ScoredActionPicker")

		controller.destroy()
	end)

	it("creates a non-competing picker for a Roblox touch button", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker = provider:GetOrCreatePicker("TouchButton")

		expect((picker :: any).ClassName).toBe("TouchButtonScoredActionPicker")

		controller.destroy()
	end)

	it("reuses the picker for slotted touch buttons sharing a slot", function()
		local controller = setup()
		local provider = controller.newProvider()

		local first = provider:GetOrCreatePicker(controller.slot("primary1"))
		local second = provider:GetOrCreatePicker(controller.slot("primary1"))

		expect(second).toBe(first)

		controller.destroy()
	end)

	it("creates a separate picker per slot", function()
		local controller = setup()
		local provider = controller.newProvider()

		local first = provider:GetOrCreatePicker(controller.slot("primary1"))
		local second = provider:GetOrCreatePicker(controller.slot("primary2"))

		expect(second).never.toBe(first)

		controller.destroy()
	end)

	it("throws on a nil input type", function()
		local controller = setup()
		local provider = controller.newProvider()

		expect(function()
			(provider :: any):GetOrCreatePicker(nil)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("ScoredActionPickerProvider.FindPicker", function()
	it("returns nil for an input type with no picker", function()
		local controller = setup()
		local provider = controller.newProvider()

		expect(provider:FindPicker(Enum.KeyCode.E)).toBeNil()

		controller.destroy()
	end)

	it("finds a created picker", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker = provider:GetOrCreatePicker(Enum.KeyCode.E)

		expect(provider:FindPicker(Enum.KeyCode.E)).toBe(picker)

		controller.destroy()
	end)

	it("finds a slotted touch button picker by an equivalent slot", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker = provider:GetOrCreatePicker(controller.slot("inner1"))

		expect(provider:FindPicker(controller.slot("inner1"))).toBe(picker)

		controller.destroy()
	end)
end)

describe("ScoredActionPickerProvider.Update", function()
	it("discards a picker that has no actions", function()
		local controller = setup()
		local provider = controller.newProvider()

		provider:GetOrCreatePicker(Enum.KeyCode.E)
		provider:Update()

		expect(provider:FindPicker(Enum.KeyCode.E)).toBeNil()

		controller.destroy()
	end)

	it("keeps a picker that still has actions", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker: any = provider:GetOrCreatePicker(Enum.KeyCode.E)
		picker:AddAction(controller.newAction(1))
		provider:Update()

		expect(provider:FindPicker(Enum.KeyCode.E)).toBe(picker)

		controller.destroy()
	end)

	it("updates the pickers it keeps", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker: any = provider:GetOrCreatePicker(Enum.KeyCode.E)
		local action = controller.newAction(-math.huge)
		picker:AddAction(action)

		action:SetScore(1)
		provider:Update()

		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("discards a picker once its last action is removed", function()
		local controller = setup()
		local provider = controller.newProvider()

		local picker: any = provider:GetOrCreatePicker(Enum.KeyCode.E)
		local action = controller.newAction(1)
		picker:AddAction(action)
		provider:Update()

		picker:RemoveAction(action)
		provider:Update()

		expect(provider:FindPicker(Enum.KeyCode.E)).toBeNil()

		controller.destroy()
	end)

	it("discards a touch button picker that has no actions", function()
		local controller = setup()
		local provider = controller.newProvider()

		provider:GetOrCreatePicker("TouchButton")
		provider:Update()

		expect(provider:FindPicker("TouchButton")).toBeNil()

		controller.destroy()
	end)

	it("does nothing when there are no pickers", function()
		local controller = setup()
		local provider = controller.newProvider()

		expect(function()
			provider:Update()
		end).never.toThrow()

		controller.destroy()
	end)
end)

describe("ScoredActionPickerProvider.Destroy", function()
	it("drops the preferences its pickers were holding", function()
		local controller = setup()
		local provider = controller.newLooseProvider()

		local picker: any = provider:GetOrCreatePicker(Enum.KeyCode.E)
		local action = controller.newAction(1)
		picker:AddAction(action)
		expect(action:IsPreferred()).toBe(true)

		provider:Destroy()

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)
end)
