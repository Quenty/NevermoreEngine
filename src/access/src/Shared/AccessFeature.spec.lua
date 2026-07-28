--!strict
--[[
	@class AccessFeature.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessFactContributionState = require("AccessFactContributionState")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local Rx = require("Rx")

local ALLOW = AccessFactContributionState.ALLOW
local DENY = AccessFactContributionState.DENY
local UNRESOLVED = AccessFactContributionState.UNRESOLVED

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function lastState(observable: any, maid: any): AccessStateUtils.AccessState?
	local last: AccessStateUtils.AccessState? = nil
	maid:GiveTask(observable:Subscribe(function(state)
		last = state
	end))
	return last
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
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.anyOf("thing", { "a" }))

		local names = feature:GetFactNames()
		table.insert(names, "sneakilyAdded")

		expect(feature:GetFactNames()).toEqual({ "a" })
		maid:DoCleaning()
	end)
end)

describe("AccessFeature.anyOf", function()
	it("allows when a declared fact is true", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.anyOf("thing", { "a", "b" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ a = DENY, b = ALLOW }) :: any), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)

	it("stays unresolved while a declared fact is unanswered", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.anyOf("thing", { "a", "b" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ a = DENY }) :: any), maid)

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)

	it("is unaffected by a fact it did not declare", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.anyOf("thing", { "a" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ a = DENY, unrelated = ALLOW }) :: any), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(false)
		maid:DoCleaning()
	end)
end)

describe("AccessFeature.alwaysAllowed", function()
	it("allows without reading any fact", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.alwaysAllowed("hub"))

		expect(feature:GetFactNames()).toEqual({})
		expect(AccessStateUtils.isAllowed(lastState(feature:ObserveCompute(Rx.of({}) :: any), maid) :: any)).toEqual(
			true
		)

		maid:DoCleaning()
	end)
end)

describe("AccessFeature.ObserveCompute", function()
	it("passes the subject through to the observeCompute", function()
		local maid = Maid.new()
		local seen = nil

		local feature = maid:Add(AccessFeature.new("eggPurchase", {
			facts = {},
			observeCompute = function(_observeFacts, subject)
				seen = subject
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		lastState(feature:ObserveCompute(Rx.of({}) :: any, "blueEgg"), maid)

		expect(seen).toEqual("blueEgg")
		maid:DoCleaning()
	end)

	it("lets a feature fold in context that is not a fact", function()
		-- The whole reason observeCompute returns an Observable rather than a verdict: an egg's asset and whether
		-- it has been collected are per-egg, not per-player, so they are not facts.
		local maid = Maid.new()

		local feature = maid:Add(AccessFeature.new("eggPurchase", {
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

		local state = lastState(feature:ObserveCompute(Rx.of({ ownsGame = ALLOW }) :: any), maid)

		expect((state :: any).reason).toEqual("eggNotCollected")
		maid:DoCleaning()
	end)

	it("refuses a observeCompute that returns a verdict instead of an observable", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.new("thing", {
			facts = {},
			observeCompute = function()
				return AccessStateUtils.allowed() :: any
			end,
		}))

		expect(function()
			feature:ObserveCompute(Rx.of({}) :: any)
		end).toThrow("must return an Observable")
		maid:DoCleaning()
	end)
end)

describe("AccessFeature context", function()
	--[[
		Facts are per-player, so a per-thing input -- an egg's asset, whether it has been collected -- cannot
		be one. Declaring them instead of closing over them is what lets a readout print them.
	]]
	it("hands the declared context to observeCompute, resolved against the subject", function()
		local maid = Maid.new()
		local seen = nil

		local feature = maid:Add(AccessFeature.new("eggPurchase", {
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

		lastState(feature:ObserveCompute(Rx.of({}) :: any, "blueEgg"), maid)

		expect((seen :: any).hasCollected).toEqual(true)
		maid:DoCleaning()
	end)

	it("names what it reads, so a report can print it", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.new("eggPurchase", {
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

		maid:DoCleaning()
	end)

	it("emits an empty table for a feature that declared none", function()
		-- Rather than never emitting: a caller combines context in unconditionally, and a source that never
		-- fires would leave every such feature unresolved forever.
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.anyOf("thing", { "a" }))

		local seen = nil
		maid:GiveTask(feature:ObserveContext(nil):Subscribe(function(context)
			seen = context
		end))

		expect(seen).toEqual({})
		maid:DoCleaning()
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
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))

		local both = lastState(feature:ObserveCompute(Rx.of({ isTester = ALLOW, flagOn = ALLOW }) :: any), maid)
		expect(AccessStateUtils.isAllowed(both :: any)).toEqual(true)

		local one = lastState(feature:ObserveCompute(Rx.of({ isTester = ALLOW, flagOn = DENY }) :: any), maid)
		expect(AccessStateUtils.isAllowed(one :: any)).toEqual(false)

		maid:DoCleaning()
	end)

	it("refuses outright on a denial rather than waiting on an unanswered one", function()
		-- No later answer can rescue an and-of, so reporting unresolved would be a stall with a known
		-- answer already behind it.
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ flagOn = DENY }) :: any), maid)

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(false)
		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(false)

		maid:DoCleaning()
	end)

	it("stays unresolved while a term is unanswered and none has denied", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ isTester = ALLOW }) :: any), maid)

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)

	it("lets a pushed fact widen it rather than join the and", function()
		-- PushFactAllowsFeature promises it can grant and never deny. An and-of that took pushed facts as
		-- further terms would break that promise in the one direction nobody would expect.
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.allOf("earlyAccess", { "isTester", "flagOn" }))
		maid:GiveTask(feature:PushFactNameAllowsFeature("isStaff"))

		local state = lastState(feature:ObserveCompute(Rx.of({ isTester = DENY, isStaff = ALLOW }) :: any), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)
end)

describe("AccessFeature.noneOf", function()
	it("allows when the fact is definitely false", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ ownsGame = DENY }) :: any), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)

	it("refuses when the fact is true", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ ownsGame = ALLOW }) :: any), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(false)
		maid:DoCleaning()
	end)

	it("stays unresolved rather than reading a failed lookup as a no", function()
		-- The bug this exists to prevent: `not value` turns unresolved into true, and a purchase gate then
		-- offers to sell somebody what they may already own.
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = lastState(feature:ObserveCompute(Rx.of({ ownsGame = UNRESOLVED }) :: any), maid)

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)
		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(false)

		maid:DoCleaning()
	end)

	it("treats a fact nothing answered the same as an unresolved one", function()
		local maid = Maid.new()
		local feature = maid:Add(AccessFeature.noneOf("canPurchaseGame", { "ownsGame" }))

		local state = lastState(feature:ObserveCompute(Rx.of({}) :: any), maid)

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)
end)
