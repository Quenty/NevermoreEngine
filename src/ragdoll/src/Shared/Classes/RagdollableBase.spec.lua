--!strict
--[[
	@class RagdollableBase.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local RagdollableBase = require("RagdollableBase")
local SignalTestUtils = require("SignalTestUtils")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local isRagdolled = maid:Add(ValueObject.new(false, "boolean"))

	local humanoid = maid:Add(Instance.new("Humanoid"))
	local ragdollable: any = maid:Add(RagdollableBase.new(humanoid))
	ragdollable.ObserveIsRagdolled = function()
		return isRagdolled:Observe()
	end

	local controller = {
		isRagdolled = isRagdolled,
		ragdolledCount = SignalTestUtils.countFires(maid, ragdollable.Ragdolled),
		unragdolledCount = SignalTestUtils.countFires(maid, ragdollable.Unragdolled),
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RagdollableBase", function()
	it("fires neither signal for the initial state", function()
		local controller = setup()

		expect(controller.ragdolledCount()).toEqual(0)
		expect(controller.unragdolledCount()).toEqual(0)
	end)

	it("fires only Ragdolled on ragdoll", function()
		local controller = setup()

		controller.isRagdolled.Value = true

		expect(controller.ragdolledCount()).toEqual(1)
		expect(controller.unragdolledCount()).toEqual(0)
	end)

	it("fires Unragdolled on unragdoll", function()
		local controller = setup()

		controller.isRagdolled.Value = true
		controller.isRagdolled.Value = false

		expect(controller.ragdolledCount()).toEqual(1)
		expect(controller.unragdolledCount()).toEqual(1)
	end)
end)
