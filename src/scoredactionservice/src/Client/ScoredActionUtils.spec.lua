--!strict
--[[
	@class ScoredActionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ScoredAction = require("ScoredAction")
local ScoredActionUtils = require("ScoredActionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newAction: () -> ScoredAction.ScoredAction,
	connect: (ScoredAction.ScoredAction, (Maid.Maid) -> ()) -> Maid.Maid,
	connectLoose: (ScoredAction.ScoredAction, (Maid.Maid) -> ()) -> Maid.Maid,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newAction = function()
			return maid:Add(ScoredAction.new()) :: any
		end,

		connect = function(action, callback)
			return maid:Add(ScoredActionUtils.connectToPreferred(action, callback)) :: any
		end,

		connectLoose = function(action, callback)
			return ScoredActionUtils.connectToPreferred(action, callback)
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("ScoredActionUtils.connectToPreferred", function()
	it("does not invoke the callback for an unpreferred action", function()
		local controller = setup()
		local action = controller.newAction()

		local calls = 0
		controller.connect(action, function()
			calls += 1
		end)

		expect(calls).toBe(0)

		controller:Destroy()
	end)

	it("invokes the callback immediately for an already preferred action", function()
		local controller = setup()
		local action = controller.newAction()
		action:PushPreferred()

		local calls = 0
		controller.connect(action, function()
			calls += 1
		end)

		expect(calls).toBe(1)

		controller:Destroy()
	end)

	it("invokes the callback when the action becomes preferred", function()
		local controller = setup()
		local action = controller.newAction()

		local calls = 0
		controller.connect(action, function()
			calls += 1
		end)

		action:PushPreferred()

		expect(calls).toBe(1)

		controller:Destroy()
	end)

	it("does not re-invoke the callback for a second push", function()
		local controller = setup()
		local action = controller.newAction()

		local calls = 0
		controller.connect(action, function()
			calls += 1
		end)

		action:PushPreferred()
		action:PushPreferred()

		expect(calls).toBe(1)

		controller:Destroy()
	end)

	it("invokes the callback again on a later push", function()
		local controller = setup()
		local action = controller.newAction()

		local calls = 0
		controller.connect(action, function()
			calls += 1
		end)

		action:PushPreferred()()
		action:PushPreferred()

		expect(calls).toBe(2)

		controller:Destroy()
	end)

	it("cleans up the callback maid when the action stops being preferred", function()
		local controller = setup()
		local action = controller.newAction()

		local cleaned = false
		controller.connect(action, function(preferredMaid)
			preferredMaid:GiveTask(function()
				cleaned = true
			end)
		end)

		local pop = action:PushPreferred()
		expect(cleaned).toBe(false)

		pop()

		expect(cleaned).toBe(true)

		controller:Destroy()
	end)

	it("cleans up the callback maid when the returned maid is destroyed", function()
		local controller = setup()
		local action = controller.newAction()
		action:PushPreferred()

		local cleaned = false
		local topMaid = controller.connectLoose(action, function(preferredMaid)
			preferredMaid:GiveTask(function()
				cleaned = true
			end)
		end)

		topMaid:DoCleaning()

		expect(cleaned).toBe(true)

		controller:Destroy()
	end)

	it("cleans up a callback maid abandoned by a pop during the callback", function()
		local controller = setup()
		local action = controller.newAction()
		local pop = action:PushPreferred()

		local cleaned = false
		controller.connect(action, function(preferredMaid)
			preferredMaid:GiveTask(function()
				cleaned = true
			end)

			pop()
		end)

		expect(action:IsPreferred()).toBe(false)
		expect(cleaned).toBe(true)

		controller:Destroy()
	end)
end)
