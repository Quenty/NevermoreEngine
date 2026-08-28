--!strict
--[[
	@class AccessFact.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessFact = require("AccessFact")
local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactPriority = require("AccessFactPriority")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- A hot source a test drives by hand. Nevermore has no Subject, and a fact has to be observed while its
-- answer is still outstanding, which no cold observable lets us stage.
local function controllable()
	local subs: { any } = {}

	local observable = Observable.new(function(sub)
		table.insert(subs, sub)

		return function()
			local index = table.find(subs, sub)
			if index then
				table.remove(subs, index)
			end
		end
	end)

	return observable,
		{
			fire = function(value: boolean?)
				for _, sub in table.clone(subs) do
					sub:Fire(value)
				end
			end,
			fail = function()
				for _, sub in table.clone(subs) do
					sub:Fail("lookup exploded")
				end
			end,
		}
end

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())

	local controller = {
		serviceBag = serviceBag,
		maid = maid,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		fact = function(resolver: any): AccessFact.AccessFact
			local fact = maid:Add(AccessFact.new("fact", { resolve = resolver })) :: any
			fact:Init(serviceBag)
			return fact
		end,
		-- A layer emits a contribution: nil for abstained, or a box whose value may itself be nil. Neither
		-- survives a plain list, so record every emission flattened into a table that is always present.
		record = function(observable: any): { { value: boolean?, abstained: boolean } }
			local emitted: { { value: boolean?, abstained: boolean } } = {}
			maid:GiveTask(observable:Subscribe(function(contribution: any)
				table.insert(emitted, {
					value = contribution.value,
					abstained = contribution.state == AccessFactContributionState.ABSTAIN,
				})
			end))
			return emitted
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessFact.new", function()
	it("rejects an empty fact name", function()
		expect(function()
			AccessFact.new("", {
				resolve = function()
					return nil
				end,
			})
		end).toThrow("Bad factName")
	end)

	it("rejects options with neither a resolver nor a value", function()
		expect(function()
			AccessFact.new("something", nil :: any)
		end).toThrow("Bad options")
	end)
end)

describe("AccessFact.ObserveForPlayer", function()
	it("emits unresolved before the resolver has answered", function()
		-- Otherwise combineLatest across several facts produces nothing until the slowest lookup lands, and
		-- a live consumer renders nothing rather than "not yet known".
		local controller = setup()
		local source = controllable()

		local emitted = controller.record(controller
			.fact(function()
				return source
			end)
			:ObserveForPlayer(controller.fakePlayer()))

		expect(#emitted).toEqual(1)
		expect(emitted[1].value).toEqual(nil)

		controller:Destroy()
	end)

	it("emits the resolved value after the resolver answers", function()
		local controller = setup()
		local source, drive = controllable()

		local emitted = controller.record(controller
			.fact(function()
				return source
			end)
			:ObserveForPlayer(controller.fakePlayer()))
		drive.fire(true)

		expect(#emitted).toEqual(2)
		expect(emitted[2].value).toEqual(true)

		controller:Destroy()
	end)

	it("falls back to unresolved when a resolved fact later fails", function()
		-- One broken mechanism must read as "no answer", not take down every feature that asked.
		local controller = setup()
		local source, drive = controllable()

		local emitted = controller.record(controller
			.fact(function()
				return source
			end)
			:ObserveForPlayer(controller.fakePlayer()))

		drive.fire(true)
		expect(emitted[#emitted].value).toEqual(true)

		drive.fail()
		expect(emitted[#emitted].value).toEqual(nil)

		controller:Destroy()
	end)

	it("resolves a bare boolean, so a test needs no observable", function()
		local controller = setup()

		local emitted = controller.record(controller
			.fact(function()
				return true
			end)
			:ObserveForPlayer(controller.fakePlayer()))

		expect(emitted[#emitted].value).toEqual(true)

		controller:Destroy()
	end)

	it("resolves a ValueObject and follows it", function()
		local controller = setup()
		local valueObject = controller.maid:Add(ValueObject.new(false :: boolean?))

		local emitted = controller.record(controller
			.fact(function()
				return valueObject
			end)
			:ObserveForPlayer(controller.fakePlayer()))
		valueObject.Value = true

		expect(emitted[#emitted].value).toEqual(true)

		controller:Destroy()
	end)

	it("resolves each player separately", function()
		local controller = setup()
		local seen = {}

		local fact = controller.fact(function(_serviceBag, player)
			table.insert(seen, player)
			return true
		end)

		controller.record(fact:ObserveForPlayer(controller.fakePlayer()))
		controller.record(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(#seen).toEqual(2)

		controller:Destroy()
	end)

	it("runs one resolver for concurrent readers of the same player", function()
		-- The fan-in: five surfaces asking the same question must not open five copies of the lookup.
		local controller = setup()
		local resolveCount = 0

		local fact = controller.fact(function()
			resolveCount += 1
			return true
		end)

		local player = controller.fakePlayer()
		controller.record(fact:ObserveForPlayer(player))
		controller.record(fact:ObserveForPlayer(player))
		controller.record(fact:ObserveForPlayer(player))

		expect(resolveCount).toEqual(1)

		controller:Destroy()
	end)

	it("refuses to resolve before it has been initialized", function()
		local controller = setup()

		local fact = controller.maid:Add(AccessFact.new("owns", {
			resolve = function()
				return true
			end,
		})) :: any

		expect(function()
			fact:ObserveForPlayer(controller.fakePlayer())
		end).toThrow("not initialized")

		controller:Destroy()
	end)
end)

describe("AccessFact.new with a value", function()
	it("gives every player the same answer, and follows it", function()
		local controller = setup()
		local valueObject = controller.maid:Add(ValueObject.new(true :: boolean?))

		local fact = controller.maid:Add(AccessFact.new("eventIsRunning", { value = valueObject })) :: any
		fact:Init(controller.serviceBag)

		local first = controller.record(fact:ObserveForPlayer(controller.fakePlayer()))
		local second = controller.record(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(first[#first].value).toEqual(true)
		expect(second[#second].value).toEqual(true)

		valueObject.Value = false

		expect(first[#first].value).toEqual(false)
		expect(second[#second].value).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessFact layering", function()
	it("defaults to the default priority and source", function()
		local maid = Maid.new()
		local fact = maid:Add(AccessFact.new("owns", {
			resolve = function()
				return nil
			end,
		}))

		expect(fact:GetPriority()).toEqual(AccessFactPriority.DEFAULT)
		expect(fact:GetSource()).toEqual("default")

		maid:DoCleaning()
	end)

	it("carries the priority and source it was given", function()
		local maid = Maid.new()
		local fact = maid:Add(AccessFact.new("owns", {
			resolve = function()
				return nil
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		}))

		expect(fact:GetPriority()).toEqual(AccessFactPriority.ELEVATED)
		expect(fact:GetSource()).toEqual("allowlist")

		maid:DoCleaning()
	end)

	it("contributes an answer of unresolved, which is not the same as abstaining", function()
		-- The distinction the whole merge turns on: this layer answered "nobody knows", which stops the
		-- fall-through, rather than saying nothing and letting a lower layer decide.
		local controller = setup()

		local emitted = controller.record(controller
			.fact(function()
				return nil
			end)
			:ObserveForPlayer(controller.fakePlayer()))

		expect(emitted[#emitted].abstained).toEqual(false)
		expect(emitted[#emitted].value).toEqual(nil)

		controller:Destroy()
	end)

	it("abstains when the resolver returns ABSTAIN", function()
		local controller = setup()

		local emitted = controller.record(controller
			.fact(function()
				return AccessFact.ABSTAIN
			end)
			:ObserveForPlayer(controller.fakePlayer()))

		expect(emitted[#emitted].abstained).toEqual(true)

		controller:Destroy()
	end)
end)
