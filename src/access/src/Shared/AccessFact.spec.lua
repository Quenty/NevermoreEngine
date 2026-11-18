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
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Contributions = ObservableSpy.ObservableSpy<AccessFact.AccessFactContribution>

type Source = {
	observable: Observable.Observable<boolean?>,
	fire: (value: boolean?) -> (),
	fail: () -> (),
}

type Controller = {
	maid: Maid.Maid,
	serviceBag: ServiceBag.ServiceBag,
	fakePlayer: () -> Player,
	source: () -> Source,
	fact: (resolver: AccessFact.AccessFactResolver) -> AccessFact.AccessFact,
	spy: (observable: Observable.Observable<AccessFact.AccessFactContribution>) -> Contributions,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())

	local controller: Controller = {
		maid = maid,
		serviceBag = serviceBag,
		fakePlayer = function()
			return maid:Add(PlayerMock.new())
		end,
		source = function()
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

			return {
				observable = observable,
				fire = function(value)
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
		end,
		fact = function(resolver)
			local fact = maid:Add(AccessFact.new("fact", { resolve = resolver }))
			fact:Init(serviceBag)
			return fact
		end,
		spy = function(observable)
			return maid:Add(ObservableSpy.new(observable))
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
		local controller = setup()
		local source = controller.source()

		local fact = controller.fact(function()
			return source.observable
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(#contributions).toEqual(1)
		expect(contributions[1].value).toEqual(nil)

		controller:Destroy()
	end)

	it("emits the resolved value after the resolver answers", function()
		local controller = setup()
		local source = controller.source()

		local fact = controller.fact(function()
			return source.observable
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))
		source.fire(true)

		expect(#contributions).toEqual(2)
		expect(contributions[2].value).toEqual(true)

		controller:Destroy()
	end)

	it("falls back to unresolved when a resolved fact later fails", function()
		local controller = setup()
		local source = controller.source()

		local fact = controller.fact(function()
			return source.observable
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		source.fire(true)
		expect(contributions:GetLastValue().value).toEqual(true)

		source.fail()
		expect(contributions:GetLastValue().value).toEqual(nil)

		controller:Destroy()
	end)

	it("resolves a bare boolean, so a test needs no observable", function()
		local controller = setup()

		local fact = controller.fact(function()
			return true
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(contributions:GetLastValue().value).toEqual(true)

		controller:Destroy()
	end)

	it("resolves a ValueObject and follows it", function()
		local controller = setup()
		local valueObject = controller.maid:Add(ValueObject.new(false :: boolean?))

		local fact = controller.fact(function()
			return valueObject
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))
		valueObject.Value = true

		expect(contributions:GetLastValue().value).toEqual(true)

		controller:Destroy()
	end)

	it("resolves each player separately", function()
		local controller = setup()
		local seen = {}

		local fact = controller.fact(function(_serviceBag, player)
			table.insert(seen, player)
			return true
		end)

		controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))
		controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(#seen).toEqual(2)

		controller:Destroy()
	end)

	it("runs one resolver for concurrent readers of the same player", function()
		local controller = setup()
		local resolveCount = 0

		local fact = controller.fact(function()
			resolveCount += 1
			return true
		end)

		local player = controller.fakePlayer()
		controller.spy(fact:ObserveForPlayer(player))
		controller.spy(fact:ObserveForPlayer(player))
		controller.spy(fact:ObserveForPlayer(player))

		expect(resolveCount).toEqual(1)

		controller:Destroy()
	end)

	it("refuses to resolve before it has been initialized", function()
		local controller = setup()

		local fact = controller.maid:Add(AccessFact.new("owns", {
			resolve = function()
				return true
			end,
		}))

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

		local fact = controller.maid:Add(AccessFact.new("eventIsRunning", { value = valueObject }))
		fact:Init(controller.serviceBag)

		local first = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))
		local second = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(first:GetLastValue().value).toEqual(true)
		expect(second:GetLastValue().value).toEqual(true)

		valueObject.Value = false

		expect(first:GetLastValue().value).toEqual(false)
		expect(second:GetLastValue().value).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessFact layering", function()
	it("defaults to the default priority and source", function()
		local controller = setup()
		local fact = controller.maid:Add(AccessFact.new("owns", {
			resolve = function()
				return nil
			end,
		}))

		expect(fact:GetPriority()).toEqual(AccessFactPriority.DEFAULT)
		expect(fact:GetSource()).toEqual("default")

		controller:Destroy()
	end)

	it("carries the priority and source it was given", function()
		local controller = setup()
		local fact = controller.maid:Add(AccessFact.new("owns", {
			resolve = function()
				return nil
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		}))

		expect(fact:GetPriority()).toEqual(AccessFactPriority.ELEVATED)
		expect(fact:GetSource()).toEqual("allowlist")

		controller:Destroy()
	end)

	it("contributes an answer of unresolved, which is not the same as abstaining", function()
		local controller = setup()

		local fact = controller.fact(function()
			return nil
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(contributions:GetLastValue().state).never.toEqual(AccessFactContributionState.ABSTAIN)
		expect(contributions:GetLastValue().value).toEqual(nil)

		controller:Destroy()
	end)

	it("abstains when the resolver returns ABSTAIN", function()
		local controller = setup()

		local fact = controller.fact(function()
			return AccessFact.ABSTAIN
		end)
		local contributions = controller.spy(fact:ObserveForPlayer(controller.fakePlayer()))

		expect(contributions:GetLastValue().state).toEqual(AccessFactContributionState.ABSTAIN)

		controller:Destroy()
	end)
end)
