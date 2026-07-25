--!strict
--[[
	@class ScoredActionServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InputKeyMap = require("InputKeyMap")
local InputKeyMapList = require("InputKeyMapList")
local InputModeServiceClient = require("InputModeServiceClient")
local InputModeTypes = require("InputModeTypes")
local Jest = require("Jest")
local Maid = require("Maid")
local Observable = require("Observable")
local ScoredActionServiceClient = require("ScoredActionServiceClient")
local ServiceBag = require("ServiceBag")
local StepUtils = require("StepUtils")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local serviceBag: any = maid:Add(ServiceBag.new())
	local service = serviceBag:GetService(ScoredActionServiceClient)
	serviceBag:Init()
	serviceBag:Start()

	serviceBag:GetService(InputModeServiceClient):GetInputMode(InputModeTypes.Keyboard):Enable()

	-- ObserveNewFromInputKeyMapList scopes each emitted action to the subscription, so a source
	-- that completes on emission hands back an already-destroyed action.
	local function observeLists(lists: { InputKeyMapList.InputKeyMapList })
		return Observable.new(function(sub)
			for _, list in lists do
				sub:Fire(list)
			end

			return nil
		end)
	end

	local controller = {
		service = service,

		newList = function(inputTypes: { any })
			return maid:Add(InputKeyMapList.new("SPEC_SERVICE_ACTION", {
				InputKeyMap.new(InputModeTypes.Keyboard, inputTypes),
			}, {
				bindingName = "Spec Service Action",
				rebindable = false,
			})) :: any
		end,

		newAction = function(list)
			return maid:Add(service:GetScoredAction(list)) :: any
		end,

		newLooseAction = function(list)
			return service:GetScoredAction(list)
		end,

		newValue = function(score: number)
			return maid:Add(ValueObject.new(score, "number")) :: any
		end,

		-- Scores are only ranked by the service's own step connection, so they land a frame later.
		-- Two waits, because the first may be the same fire our own handler is already resuming from.
		scoreAndStep = function(action, score: number)
			action:SetScore(score)

			local signal = StepUtils.getSteppedSignal()
			signal:Wait()
			signal:Wait()
		end,

		collect = function(lists, scoreValue)
			local actions = {}
			local sub = (observeLists(lists) :: any)
				:Pipe({
					service:ObserveNewFromInputKeyMapList(scoreValue) :: any,
				})
				:Subscribe(function(action)
					table.insert(actions, action)
				end)
			maid:GiveTask(sub)

			return actions, function()
				sub:Destroy()
			end
		end,

		destroyService = function()
			service:Destroy()
		end,

		destroy = function()
			maid:DoCleaning()
		end,
	}

	return controller
end

describe("ScoredActionServiceClient.GetScoredAction", function()
	it("returns a fresh unscored action", function()
		local controller = setup()
		local action = controller.newAction(controller.newList({ Enum.KeyCode.E }))

		expect(action.ClassName).toBe("ScoredAction")
		expect(action:GetScore()).toBe(-math.huge)
		expect(action:IsEnabled()).toBe(true)
		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("throws on something that is not an inputKeyMapList", function()
		local controller = setup()

		expect(function()
			(controller.service :: any):GetScoredAction({})
		end).toThrow()

		controller.destroy()
	end)

	it("prefers the highest scoring action bound to the same key", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local low = controller.newAction(list)
		local high = controller.newAction(list)

		controller.scoreAndStep(low, 1)
		controller.scoreAndStep(high, 2)

		expect(high:IsPreferred()).toBe(true)
		expect(low:IsPreferred()).toBe(false)

		controller.destroy()
	end)

	it("hands the preference over when the winner is disabled", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local low = controller.newAction(list)
		local high = controller.newAction(list)

		controller.scoreAndStep(low, 1)
		controller.scoreAndStep(high, 2)

		high:SetIsEnabled(false)

		expect(high:IsPreferred()).toBe(false)
		expect(low:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("does not make actions on different keys compete", function()
		local controller = setup()

		local first = controller.newAction(controller.newList({ Enum.KeyCode.E }))
		local second = controller.newAction(controller.newList({ Enum.KeyCode.Q }))

		controller.scoreAndStep(first, 1)
		controller.scoreAndStep(second, 2)

		expect(first:IsPreferred()).toBe(true)
		expect(second:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("releases the preference when the action is destroyed", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local action = controller.newLooseAction(list)
		controller.scoreAndStep(action, 1)
		expect(action:IsPreferred()).toBe(true)

		action:Destroy()

		expect((action :: any).Destroy).toBeNil()

		controller.destroy()
	end)

	it("lets a later action win the key a destroyed action held", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local first = controller.newLooseAction(list)
		controller.scoreAndStep(first, 5)
		first:Destroy()

		local second = controller.newAction(list)
		controller.scoreAndStep(second, 1)

		expect(second:IsPreferred()).toBe(true)

		controller.destroy()
	end)
end)

describe("ScoredActionServiceClient.ObserveNewFromInputKeyMapList", function()
	it("throws on something that is not a valueObject", function()
		local controller = setup()

		expect(function()
			(controller.service :: any):ObserveNewFromInputKeyMapList({})
		end).toThrow()

		controller.destroy()
	end)

	it("emits an action carrying the current score", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local actions = controller.collect({ list }, controller.newValue(5))

		expect(#actions).toBe(1)
		expect(actions[1]:GetScore()).toBe(5)

		controller.destroy()
	end)

	it("follows later changes to the score value", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })
		local scoreValue = controller.newValue(5)

		local actions = controller.collect({ list }, scoreValue)
		scoreValue.Value = 9

		expect(actions[1]:GetScore()).toBe(9)

		controller.destroy()
	end)

	it("emits once for a repeated inputKeyMapList", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local actions = controller.collect({ list, list }, controller.newValue(1))

		expect(#actions).toBe(1)

		controller.destroy()
	end)

	it("emits again for a different inputKeyMapList", function()
		local controller = setup()
		local first = controller.newList({ Enum.KeyCode.E })
		local second = controller.newList({ Enum.KeyCode.Q })

		local actions = controller.collect({ first, second }, controller.newValue(1))

		expect(#actions).toBe(2)
		expect(actions[2]).never.toBe(actions[1])

		controller.destroy()
	end)

	it("destroys the previous action when a new one is emitted", function()
		local controller = setup()
		local first = controller.newList({ Enum.KeyCode.E })
		local second = controller.newList({ Enum.KeyCode.Q })

		local actions = controller.collect({ first, second }, controller.newValue(1))

		expect(actions[1].Destroy).toBeNil()
		expect(actions[2].Destroy).never.toBeNil()

		controller.destroy()
	end)

	it("destroys the emitted action when the subscription ends", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local actions, unsubscribe = controller.collect({ list }, controller.newValue(1))
		unsubscribe()

		expect(actions[1].Destroy).toBeNil()

		controller.destroy()
	end)
end)

describe("ScoredActionServiceClient.Start", function()
	it("re-ranks a rescored action on the step signal alone", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local action = controller.newAction(list)
		expect(action:IsPreferred()).toBe(false)

		controller.scoreAndStep(action, 1)

		expect(action:IsPreferred()).toBe(true)

		controller.destroy()
	end)

	it("stops re-ranking once the service is destroyed", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local action = controller.newAction(list)
		controller.destroyService()

		controller.scoreAndStep(action, 1)

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)
end)

describe("ScoredActionServiceClient.Destroy", function()
	it("releases the preferences its actions were holding", function()
		local controller = setup()
		local list = controller.newList({ Enum.KeyCode.E })

		local action = controller.newAction(list)
		controller.scoreAndStep(action, 1)
		expect(action:IsPreferred()).toBe(true)

		controller.destroyService()

		expect(action:IsPreferred()).toBe(false)

		controller.destroy()
	end)
end)
