--!strict
--[[
	@class AccessDataService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	return {
		serviceBag = serviceBag,
		accessDataService = accessDataService,
		maid = maid,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		-- Registers a fact backed by a ValueObject the test drives, and hands back the ValueObject.
		fact = function(
			factName: string,
			initial: boolean?,
			options: { priority: number?, source: string? }?
		): ValueObject.ValueObject<boolean?>
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
				priority = if options then options.priority else nil,
				source = if options then options.source else nil,
			}))))
			return valueObject
		end,
		abstainingFact = function(factName: string, options: { priority: number, source: string })
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return AccessFact.ABSTAIN
				end,
				priority = options.priority,
				source = options.source,
			}))))
		end,
		feature = function(featureName: string, factNames: { string }): AccessFeature.AccessFeature
			local feature = maid:Add(AccessFeature.anyOf(featureName, factNames))
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		lastState = function(observable: any): AccessStateUtils.AccessState?
			local last: AccessStateUtils.AccessState? = nil
			maid:GiveTask(observable:Subscribe(function(state)
				last = state
			end))
			return last
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("AccessDataService registration", function()
	it("refuses two layers of one fact at the same priority", function()
		-- Equal priorities would make the winner depend on load order, which is the kind of thing nobody
		-- can debug from a complaint.
		local controller = setup()
		controller.fact("ownsChapterPass", true)

		expect(function()
			controller.fact("ownsChapterPass", false, { source = "other" })
		end).toThrow("already has a layer at priority")

		controller:destroy()
	end)

	it("refuses two layers of one fact sourced the same", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)

		expect(function()
			controller.fact("ownsChapterPass", false, { priority = AccessFactPriority.ELEVATED })
		end).toThrow("already has a layer sourced")

		controller:destroy()
	end)

	it("refuses a layer registering above the override priority", function()
		local controller = setup()

		expect(function()
			controller.fact("ownsChapterPass", true, { priority = AccessFactPriority.OVERRIDE })
		end).toThrow("cannot register at or above the override priority")

		controller:destroy()
	end)

	it("refuses two features under one name", function()
		local controller = setup()
		controller.feature("chapters", {})

		expect(function()
			controller.feature("chapters", {})
		end).toThrow("already registered")

		controller:destroy()
	end)

	it("unregisters a fact when the registration is disposed", function()
		local controller = setup()

		local dispose = controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("temporary", {
			resolve = function()
				return true
			end,
		})))
		expect(controller.accessDataService:HasFact("temporary")).toEqual(true)

		dispose()
		expect(controller.accessDataService:HasFact("temporary")).toEqual(false)

		controller:destroy()
	end)

	it("lists what is registered, for console commands working from strings", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		controller.feature("chapters", { "ownsChapterPass" })

		expect(controller.accessDataService:GetFactNames()).toEqual({
			"ownsChapterPass",
			AccessFactNames.OWNS_GAME,
			AccessFactNames.PLAYER_IS_ADMIN,
		})
		expect(controller.accessDataService:GetFeatureNames()).toEqual({
			"chapters",
			WellKnownAccessFeatureNames.OWNS_GAME,
		})

		controller:destroy()
	end)
end)

describe("AccessDataService.AddAccessFact", function()
	it("registers a fact every player reads the same answer from", function()
		local controller = setup()
		local eventRunning = controller.maid:Add(ValueObject.new(true :: boolean?)) :: any

		controller.maid:GiveTask(controller.accessDataService:AddAccessFact("eventIsRunning", eventRunning))
		local feature = controller.feature("eventReward", { "eventIsRunning" })

		local first =
			controller.lastState(controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature))
		local second =
			controller.lastState(controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature))

		expect(AccessStateUtils.isAllowed(first :: any)).toEqual(true)
		expect(AccessStateUtils.isAllowed(second :: any)).toEqual(true)

		controller:destroy()
	end)
end)

describe("AccessDataService.ObserveFeature", function()
	it("emits a verdict immediately rather than nothing", function()
		-- A live surface must have something to render before any lookup lands.
		local controller = setup()
		controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local state =
			controller.lastState(controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature))

		expect(AccessStateUtils.isUnresolved(state :: any)).toEqual(true)

		controller:destroy()
	end)

	it("follows the facts as they resolve", function()
		local controller = setup()
		local ownsGame = controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local last: AccessStateUtils.AccessState? = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		ownsGame.Value = true
		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		ownsGame.Value = false
		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(false)
		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(false)

		controller:destroy()
	end)

	it("does not stall on a fact the feature never declared", function()
		-- One dead mechanism must only block the features that actually read it.
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		controller.fact("neverAnswers", nil)

		local feature = controller.feature("chapters", { "ownsChapterPass" })
		local state =
			controller.lastState(controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature))

		expect(AccessStateUtils.isAllowed(state :: any)).toEqual(true)

		controller:destroy()
	end)

	it("reads a fact this realm never registered as unresolved, without taking the subscriber down", function()
		-- A feature re-derives its fact list live, so an unregistered fact also happens when one is
		-- removed underneath a live subscription. Throwing there kills whatever was watching.
		local controller = setup()
		local feature = controller.feature("chapters", { "registeredOnlyOnTheServer" })

		local last = nil
		expect(function()
			controller.maid:GiveTask(
				controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature):Subscribe(function(state)
					last = state
				end)
			)
		end).never.toThrow()

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("still errors when a missing fact is asked for directly", function()
		-- Direct calls are a human asking about a specific fact, where silence is the unhelpful answer.
		local controller = setup()

		expect(function()
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "nosuch")
		end).toThrow("is registered here and none has been replicated")

		controller:destroy()
	end)

	it("keeps each player's verdict to themselves", function()
		local controller = setup()
		local byPlayer: { [any]: boolean } = {}

		controller.maid:GiveTask(controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("owns", {
			resolve = function(_bag, player)
				return byPlayer[player] == true
			end,
		}))))
		local feature = controller.feature("chapters", { "owns" })

		local allowed = controller.fakePlayer()
		local denied = controller.fakePlayer()
		byPlayer[allowed] = true

		expect(
			AccessStateUtils.isAllowed(
				controller.lastState(controller.accessDataService:ObserveFeature(allowed, feature)) :: any
			)
		).toEqual(true)
		expect(
			AccessStateUtils.isAllowed(
				controller.lastState(controller.accessDataService:ObserveFeature(denied, feature)) :: any
			)
		).toEqual(false)

		controller:destroy()
	end)
end)

describe("AccessDataService.PromiseFeature", function()
	it("stays pending while the verdict is unresolved", function()
		-- A gate that settled on a non-answer would be deciding by coin toss.
		local controller = setup()
		controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local promise =
			controller.maid:GivePromise(controller.accessDataService:PromiseFeature(controller.fakePlayer(), feature))

		expect(promise:IsPending()).toEqual(true)

		controller:destroy()
	end)

	it("settles once a real verdict arrives", function()
		local controller = setup()
		local ownsGame = controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local promise =
			controller.maid:GivePromise(controller.accessDataService:PromiseFeature(controller.fakePlayer(), feature))
		ownsGame.Value = true

		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _ok, state = promise:Yield()
		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:destroy()
	end)
end)

describe("AccessDataService.SetFactOverride", function()
	it("forces a fact the player does not actually have", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local last: AccessStateUtils.AccessState? = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(false)

		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("forces unresolved, which is the state hardest to reproduce by hand", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local last: AccessStateUtils.AccessState? = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", nil)

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("restores the real value when the override is disposed", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local last: AccessStateUtils.AccessState? = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		local clear = controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		clear()
		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(false)

		controller:destroy()
	end)

	it("does not leak one player's override onto another", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local overridden = controller.fakePlayer()
		local other = controller.fakePlayer()
		controller.accessDataService:SetFactOverride(overridden, "ownsChapterPass", true)

		expect(
			AccessStateUtils.isAllowed(
				controller.lastState(controller.accessDataService:ObserveFeature(other, feature)) :: any
			)
		).toEqual(false)

		controller:destroy()
	end)

	it("refuses a fact nobody registered, so a typo is loud", function()
		local controller = setup()

		expect(function()
			controller.accessDataService:SetFactOverride(controller.fakePlayer(), "onwsGame", true)
		end).toThrow("No fact registered")

		controller:destroy()
	end)

	it("clears every override for a player at once", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local last: AccessStateUtils.AccessState? = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		controller.accessDataService:ClearFactOverrides(player)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(false)

		controller:destroy()
	end)
end)

describe("AccessDataService.ObserveFactReport", function()
	it("names the layer that decided", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true, { source = "purchase" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "ownsChapterPass")
		) :: any

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("purchase")

		controller:destroy()
	end)

	it("lets the highest-priority layer win", function()
		local controller = setup()
		controller.fact("isStaff", false, { source = "groupRank" })
		controller.fact("isStaff", true, { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "isStaff")
		) :: any

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("allowlist")

		controller:destroy()
	end)

	it("falls through a layer that abstains", function()
		local controller = setup()
		controller.fact("isStaff", true, { source = "groupRank" })
		controller.abstainingFact("isStaff", { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "isStaff")
		) :: any

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("groupRank")

		controller:destroy()
	end)

	it("falls through a layer that answers unresolved to one that knows", function()
		-- An observation of "I do not know" must not outrank a lower layer that does. This is what keeps a
		-- fact the client cannot compute from hanging when something underneath could have settled it.
		local controller = setup()
		controller.fact("isStaff", true, { source = "groupRank" })
		controller.fact("isStaff", nil, { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "isStaff")
		) :: any

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("groupRank")

		controller:destroy()
	end)

	it("lists every layer, highest priority first, with the losers still visible", function()
		local controller = setup()
		controller.fact("isStaff", false, { source = "groupRank" })
		controller.fact("isStaff", true, { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "isStaff")
		) :: any

		-- override on top, then the registered layers, then the replicated one -- which abstains here
		-- because nothing has been replicated.
		expect(#report.layers).toEqual(4)
		expect(report.layers[1].source).toEqual("override")
		expect(report.layers[1].contributes).toEqual(false)
		expect(report.layers[2].source).toEqual("allowlist")
		expect(report.layers[2].decided).toEqual(true)
		expect(report.layers[3].source).toEqual("groupRank")
		expect(report.layers[3].contributes).toEqual(true)
		expect(report.layers[3].decided).toEqual(false)
		expect(report.layers[3].value).toEqual(false)
		expect(report.layers[4].source).toEqual("replicated")
		expect(report.layers[4].contributes).toEqual(false)

		controller:destroy()
	end)

	it("shows an override as its own layer with the real answer still underneath", function()
		-- Collapse these and nobody can tell a genuine entitlement from an override someone left on.
		local controller = setup()
		controller.fact("ownsChapterPass", false, { source = "purchase" })

		local player = controller.fakePlayer()
		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)

		local report =
			controller.lastState(controller.accessDataService:ObserveFactReport(player, "ownsChapterPass")) :: any

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("override")
		expect(report.layers[2].source).toEqual("purchase")
		expect(report.layers[2].value).toEqual(false)

		controller:destroy()
	end)

	it("is unresolved with no decider when every layer abstains", function()
		local controller = setup()
		controller.abstainingFact("isStaff", { priority = AccessFactPriority.DEFAULT, source = "groupRank" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFactReport(controller.fakePlayer(), "isStaff")
		) :: any

		expect(report.value).toEqual(nil)
		expect(report.decidedBy).toEqual(nil)

		controller:destroy()
	end)
end)

describe("AccessDataService.ObserveFeatureReport", function()
	it("returns the verdict together with the facts it was reached from", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false, { source = "purchase" })
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local report = controller.lastState(
			controller.accessDataService:ObserveFeatureReport(controller.fakePlayer(), feature)
		) :: any

		expect(report.featureName).toEqual("chapters")
		expect(AccessStateUtils.isAllowed(report.state)).toEqual(false)
		expect(report.facts.ownsChapterPass.decidedBy).toEqual("purchase")
		expect(report.facts.ownsChapterPass.value).toEqual(false)

		controller:destroy()
	end)
end)

describe("AccessDataService.TeardownPlayer", function()
	it("rejects a promise still waiting on a verdict", function()
		-- Otherwise a gate outlives the session it was gating, holding the player object with it.
		local controller = setup()
		controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local promise = controller.maid:GivePromise(controller.accessDataService:PromiseFeature(player, feature))
		expect(promise:IsPending()).toEqual(true)

		controller.accessDataService:TeardownPlayer(player)

		expect(promise:IsRejected()).toEqual(true)

		controller:destroy()
	end)

	it("leaves a promise that already settled alone", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local promise = controller.maid:GivePromise(controller.accessDataService:PromiseFeature(player, feature))
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)

		controller.accessDataService:TeardownPlayer(player)

		expect(promise:IsFulfilled()).toEqual(true)

		controller:destroy()
	end)

	it("completes a live feature subscription", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local completed = false
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFeature(player, feature):Subscribe(nil, nil, function()
				completed = true
			end)
		)

		expect(completed).toEqual(false)
		controller.accessDataService:TeardownPlayer(player)
		expect(completed).toEqual(true)

		controller:destroy()
	end)

	it("completes rather than hanging for a player who already left", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		controller.accessDataService:TeardownPlayer(player)

		local completed = false
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFeature(player, feature):Subscribe(nil, nil, function()
				completed = true
			end)
		)

		expect(completed).toEqual(true)

		controller:destroy()
	end)

	it("drops the player's overrides", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)

		local player = controller.fakePlayer()
		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		controller.accessDataService:TeardownPlayer(player)

		expect(controller.accessDataService:ObserveIsPlayerPresent(player)).never.toEqual(nil)

		controller:destroy()
	end)

	it("drops every fact layer's cached resolution for that player", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)

		local player = controller.fakePlayer()
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFactReport(player, "ownsChapterPass"):Subscribe(function() end)
		)

		controller.accessDataService:TeardownPlayer(player)

		for _, layer in controller.accessDataService:GetFactLayers("ownsChapterPass") do
			expect((layer :: any)._observableByPlayer[player]).toEqual(nil)
		end

		controller:destroy()
	end)
end)

describe("AccessDataService.ObserveIsPlayerPresent", function()
	it("reports a player as here until they are torn down", function()
		local controller = setup()
		local player = controller.fakePlayer()

		local present = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveIsPlayerPresent(player):Subscribe(function(value)
			present = value
		end))

		expect(present).toEqual(true)
		controller.accessDataService:TeardownPlayer(player)
		expect(present).toEqual(false)

		controller:destroy()
	end)
end)
