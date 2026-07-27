--!strict
--[[
	@class AccessFeature.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local Rx = require("Rx")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function lastState(observable: any, maid: Maid.Maid): AccessStateUtils.AccessState?
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
		local feature = AccessFeature.anyOf("thing", { "a" })

		local names = feature:GetFactNames()
		table.insert(names, "sneakilyAdded")

		expect(feature:GetFactNames()).toEqual({ "a" })
	end)
end)

describe("AccessFeature.anyOf", function()
	it("allows when a declared fact is true", function()
		local maid = Maid.new()
		local feature = AccessFeature.anyOf("thing", { "a", "b" })

		local state = lastState(feature:ObserveCompute(Rx.of({ a = false, b = true })), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)

	it("stays unresolved while a declared fact is unanswered", function()
		local maid = Maid.new()
		local feature = AccessFeature.anyOf("thing", { "a", "b" })

		local state = lastState(feature:ObserveCompute(Rx.of({ a = false })), maid)

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)
		maid:DoCleaning()
	end)

	it("is unaffected by a fact it did not declare", function()
		local maid = Maid.new()
		local feature = AccessFeature.anyOf("thing", { "a" })

		local state = lastState(feature:ObserveCompute(Rx.of({ a = false, unrelated = true })), maid)

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(false)
		maid:DoCleaning()
	end)
end)

describe("AccessFeature.alwaysAllowed", function()
	it("allows without reading any fact", function()
		local maid = Maid.new()
		local feature = AccessFeature.alwaysAllowed("hub")

		expect(feature:GetFactNames()).toEqual({})
		expect(AccessStateUtils.isAllowed(lastState(feature:ObserveCompute(Rx.of({})), maid) :: any)).toEqual(true)

		maid:DoCleaning()
	end)
end)

describe("AccessFeature.ObserveCompute", function()
	it("passes the subject through to the observeCompute", function()
		local maid = Maid.new()
		local seen = nil

		local feature = AccessFeature.new("eggPurchase", {
			facts = {},
			observeCompute = function(_observeFacts, subject)
				seen = subject
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		})

		lastState(feature:ObserveCompute(Rx.of({}), "blueEgg"), maid)

		expect(seen).toEqual("blueEgg")
		maid:DoCleaning()
	end)

	it("lets a feature fold in context that is not a fact", function()
		-- The whole reason observeCompute returns an Observable rather than a verdict: an egg's asset and whether
		-- it has been collected are per-egg, not per-player, so they are not facts.
		local maid = Maid.new()

		local feature = AccessFeature.new("eggPurchase", {
			facts = { "ownsGame" },
			observeCompute = function(observeFacts)
				return Rx.combineLatest({
					facts = observeFacts,
					hasCollected = Rx.of(false),
				}):Pipe({
					Rx.map(function(latest)
						if not latest.hasCollected then
							return AccessStateUtils.disallowed("eggNotCollected")
						end
						return AccessStateUtils.fromFacts(latest.facts, { "ownsGame" })
					end) :: any,
				}) :: any
			end,
		})

		local state = lastState(feature:ObserveCompute(Rx.of({ ownsGame = true })), maid)

		expect((state :: any).reason).toEqual("eggNotCollected")
		maid:DoCleaning()
	end)

	it("refuses a observeCompute that returns a verdict instead of an observable", function()
		local feature = AccessFeature.new("thing", {
			facts = {},
			observeCompute = function()
				return AccessStateUtils.allowed() :: any
			end,
		})

		expect(function()
			feature:ObserveCompute(Rx.of({}))
		end).toThrow("must return an Observable")
	end)
end)
