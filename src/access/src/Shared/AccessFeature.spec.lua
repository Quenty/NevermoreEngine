--!strict
--[[
	@class AccessFeature.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessFactContributionState = require("AccessFactContributionState")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local Rx = require("Rx")

local ALLOW = AccessFactContributionState.ALLOW
local DENY = AccessFactContributionState.DENY
local UNRESOLVED = AccessFactContributionState.UNRESOLVED

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	compute: (
		feature: AccessFeature.AccessFeature,
		facts: { [string]: string },
		subject: any?
	) -> AccessStateUtils.AccessState,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		maid = maid,
		compute = function(feature, facts, subject)
			local states = maid:Add(ObservableSpy.new(feature:ObserveCompute(Rx.of(facts) :: any, subject)))
			return states:GetLastValue()
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessFeature.new", function()
	it("rejects options without facts", function()
		expect(function()
			AccessFeature.new("thing", { observeCompute = function() end } :: any)
		end).toThrow("Bad options.facts")
	end)

	it("rejects options without a observeCompute", function()
		expect(function()
			AccessFeature.new("thing", { facts = {} } :: any)
		end).toThrow("Bad options.observeCompute")
	end)
end)

describe("AccessFeature.GetFactNames", function()
	it("hands back a copy, so a caller cannot widen what the feature depends on", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("thing", { "a" }))

		local names = feature:GetFactNames()
		table.insert(names, "sneakilyAdded")

		expect(feature:GetFactNames()).toEqual({ "a" })

		controller:Destroy()
	end)
end)

describe("AccessFeature.anyOf", function()
	it("allows when a declared fact is true", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("thing", { "a", "b" }))

		local state = controller.compute(feature, { a = DENY, b = ALLOW })

		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:Destroy()
	end)

	it("stays unresolved while a declared fact is unanswered", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("thing", { "a", "b" }))

		local state = controller.compute(feature, { a = DENY })

		expect(AccessStateUtils.isUnresolved(state)).toEqual(true)

		controller:Destroy()
	end)

	it("is unaffected by a fact it did not declare", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("thing", { "a" }))

		local state = controller.compute(feature, { a = DENY, unrelated = ALLOW })

		expect(AccessStateUtils.isAllowed(state)).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessFeature.alwaysAllowed", function()
	it("allows without reading any fact", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.alwaysAllowed("hub"))

		expect(feature:GetFactNames()).toEqual({})
		expect(AccessStateUtils.isAllowed(controller.compute(feature, {}))).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessFeature.ObserveCompute", function()
	it("passes the subject through to the observeCompute", function()
		local controller = setup()
		local seen = nil

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
			facts = {},
			observeCompute = function(_observeFacts, subject)
				seen = subject
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		controller.compute(feature, {}, "blueEgg")

		expect(seen).toEqual("blueEgg")

		controller:Destroy()
	end)

	it("lets a feature fold in context that is not a fact", function()
		local controller = setup()

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
			facts = { "ownsGame" },
			observeCompute = function(observeFacts: any): any
				return Rx.combineLatest({
					facts = observeFacts,
					hasCollected = Rx.of(false),
				}):Pipe({
					Rx.map(function(latest: any): AccessStateUtils.AccessState
						if not latest.hasCollected then
							return AccessStateUtils.disallowed("eggNotCollected")
						end

						return AccessStateUtils.fromFacts(latest.facts, { "ownsGame" })
					end) :: any,
				}) :: any
			end,
		}))

		local state = controller.compute(feature, { ownsGame = ALLOW })

		expect(state).toEqual(AccessStateUtils.disallowed("eggNotCollected"))

		controller:Destroy()
	end)

	it("refuses a observeCompute that returns a verdict instead of an observable", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.new("thing", {
			facts = {},
			observeCompute = function()
				return AccessStateUtils.allowed() :: any
			end,
		}))

		expect(function()
			feature:ObserveCompute(Rx.of({}) :: any)
		end).toThrow("must return an Observable")

		controller:Destroy()
	end)
end)

describe("AccessFeature context", function()
	it("hands the declared context to observeCompute, resolved against the subject", function()
		local controller = setup()
		local seen = nil

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
			facts = {},
			context = {
				hasCollected = function(subject)
					return Rx.of(subject == "blueEgg")
				end,
			},
			observeCompute = function(_observeFacts, _subject, input)
				return input.observeContext:Pipe({
					Rx.map(function(context: any)
						seen = context
						return AccessStateUtils.allowed()
					end) :: any,
				}) :: any
			end,
		}))

		controller.compute(feature, {}, "blueEgg")

		expect(seen).toEqual({ hasCollected = true })

		controller:Destroy()
	end)

	it("names what it reads, so a report can print it", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
			facts = { "ownsGame" },
			context = {
				hasCollected = function()
					return Rx.of(false)
				end,
				assetId = function()
					return Rx.of(1234)
				end,
			},
			observeCompute = function()
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		expect(feature:GetContextNames()).toEqual({ "assetId", "hasCollected" })
		expect(feature:GetDebugState().context).toEqual({ "assetId", "hasCollected" })

		controller:Destroy()
	end)

	it("emits an empty table for a feature that declared none", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("thing", { "a" }))

		local contexts = controller.maid:Add(ObservableSpy.new(feature:ObserveContext(nil)))

		expect(contexts:GetValues()).toEqual({ {} })

		controller:Destroy()
	end)

	it("refuses a context entry that is not a resolver", function()
		expect(function()
			AccessFeature.new("thing", {
				facts = {},
				context = { hasCollected = false :: any },
				observeCompute = function()
					return Rx.of(AccessStateUtils.allowed()) :: any
				end,
			})
		end).toThrow("Bad options.context.hasCollected")
	end)
end)

describe("AccessFeature.allOf", function()
	it("allows only when every declared fact allows", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))

		local both = controller.compute(feature, { isTester = ALLOW, flagOn = ALLOW })
		expect(AccessStateUtils.isAllowed(both)).toEqual(true)

		local one = controller.compute(feature, { isTester = ALLOW, flagOn = DENY })
		expect(AccessStateUtils.isAllowed(one)).toEqual(false)

		controller:Destroy()
	end)

	it("refuses outright on a denial rather than waiting on an unanswered one", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))

		local state = controller.compute(feature, { flagOn = DENY })

		expect(AccessStateUtils.isUnresolved(state)).toEqual(false)
		expect(AccessStateUtils.isAllowed(state)).toEqual(false)

		controller:Destroy()
	end)

	it("stays unresolved while a term is unanswered and none has denied", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))

		local state = controller.compute(feature, { isTester = ALLOW })

		expect(AccessStateUtils.isUnresolved(state)).toEqual(true)

		controller:Destroy()
	end)

	it("lets a pushed fact widen it rather than join the and", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))
		controller.maid:GiveTask(feature:PushFactNameAllowsFeature("isStaff"))

		local state = controller.compute(feature, { isTester = DENY, isStaff = ALLOW })

		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessFeature.noneOf", function()
	it("allows when the fact is definitely false", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = controller.compute(feature, { ownsGame = DENY })

		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:Destroy()
	end)

	it("refuses when the fact is true", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = controller.compute(feature, { ownsGame = ALLOW })

		expect(AccessStateUtils.isAllowed(state)).toEqual(false)

		controller:Destroy()
	end)

	it("stays unresolved rather than reading a failed lookup as a no", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = controller.compute(feature, { ownsGame = UNRESOLVED })

		expect(AccessStateUtils.isUnresolved(state)).toEqual(true)
		expect(AccessStateUtils.isAllowed(state)).toEqual(false)

		controller:Destroy()
	end)

	it("treats a fact nothing answered the same as an unresolved one", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = controller.compute(feature, {})

		expect(AccessStateUtils.isUnresolved(state)).toEqual(true)

		controller:Destroy()
	end)
end)
