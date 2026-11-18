--!strict
--[[
	@class AccessDataService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactContributionState = require("AccessFactContributionState")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type FactOptions = { priority: number?, source: string? }

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	fakePlayer: () -> Player,
	fact: (factName: string, initial: boolean?, options: FactOptions?) -> ValueObject.ValueObject<boolean?>,
	abstainingFact: (factName: string, options: { priority: number, source: string }) -> (),
	feature: (featureName: string, factNames: { string }) -> AccessFeature.AccessFeature,
	observeFeature: (
		player: Player,
		feature: AccessFeature.AccessFeature
	) -> ObservableSpy.ObservableSpy<AccessStateUtils.AccessState>,
	observeFactReport: (
		player: Player,
		factName: string
	) -> ObservableSpy.ObservableSpy<AccessDataService.AccessFactReport>,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local controller: Controller = {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function()
			return maid:Add(PlayerMock.new()) :: any
		end,
		fact = function(factName, initial, options)
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
		abstainingFact = function(factName, options)
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return AccessFact.ABSTAIN
				end,
				priority = options.priority,
				source = options.source,
			}))))
		end,
		feature = function(featureName, factNames)
			local feature = maid:Add(AccessFeature.anyOf(featureName, factNames))
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		observeFeature = function(player, feature)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFeature(player, feature)))
		end,
		observeFactReport = function(player, factName)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFactReport(player, factName)))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessDataService registration", function()
	it("refuses two layers of one fact at the same priority", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)

		expect(function()
			controller.fact("ownsChapterPass", false, { source = "other" })
		end).toThrow("already has a layer at priority")

		controller:Destroy()
	end)

	it("refuses two layers of one fact sourced the same", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)

		expect(function()
			controller.fact("ownsChapterPass", false, { priority = AccessFactPriority.ELEVATED })
		end).toThrow("already has a layer sourced")

		controller:Destroy()
	end)

	it("refuses a layer registering above the override priority", function()
		local controller = setup()

		expect(function()
			controller.fact("ownsChapterPass", true, { priority = AccessFactPriority.OVERRIDE })
		end).toThrow("cannot register at or above the override priority")

		controller:Destroy()
	end)

	it("refuses two features under one name", function()
		local controller = setup()
		controller.feature("chapters", {})

		expect(function()
			controller.feature("chapters", {})
		end).toThrow("already registered")

		controller:Destroy()
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

		controller:Destroy()
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

		controller:Destroy()
	end)
end)

describe("AccessDataService.AddAccessFact", function()
	it("registers a fact every player reads the same answer from", function()
		local controller = setup()
		local eventRunning = controller.maid:Add(ValueObject.new(true :: boolean?)) :: any

		controller.maid:GiveTask(controller.accessDataService:AddAccessFact("eventIsRunning", eventRunning))
		local feature = controller.feature("eventReward", { "eventIsRunning" })

		local first = controller.observeFeature(controller.fakePlayer(), feature)
		local second = controller.observeFeature(controller.fakePlayer(), feature)

		expect(AccessStateUtils.isAllowed(first:GetLastValue())).toEqual(true)
		expect(AccessStateUtils.isAllowed(second:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessDataService.ObserveFeature", function()
	it("emits a verdict immediately rather than nothing", function()
		local controller = setup()
		controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local states = controller.observeFeature(controller.fakePlayer(), feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("follows the facts as they resolve", function()
		local controller = setup()
		local ownsGame = controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local states = controller.observeFeature(controller.fakePlayer(), feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		ownsGame.Value = true
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		ownsGame.Value = false
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)
		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)

	it("does not stall on a fact the feature never declared", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		controller.fact("neverAnswers", nil)

		local feature = controller.feature("chapters", { "ownsChapterPass" })
		local states = controller.observeFeature(controller.fakePlayer(), feature)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("reads a fact this realm never registered as unresolved, without taking the subscriber down", function()
		local controller = setup()
		local feature = controller.feature("chapters", { "registeredOnlyOnTheServer" })

		local states = controller.observeFeature(controller.fakePlayer(), feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("reads a fact nothing here has heard of as unresolved rather than throwing", function()
		local controller = setup()

		local reports = controller.observeFactReport(controller.fakePlayer(), "nosuch")
		local report = reports:GetLastValue()

		expect(report.state).toEqual(AccessFactContributionState.UNRESOLVED)
		expect(report.value).toEqual(nil)

		controller:Destroy()
	end)

	it("keeps each player's verdict to themselves", function()
		local controller = setup()
		local byPlayer: { [Player]: boolean } = {}

		controller.maid:GiveTask(controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("owns", {
			resolve = function(_bag, player)
				return byPlayer[player] == true
			end,
		}))))
		local feature = controller.feature("chapters", { "owns" })

		local allowed = controller.fakePlayer()
		local denied = controller.fakePlayer()
		byPlayer[allowed] = true

		local allowedStates = controller.observeFeature(allowed, feature)
		local deniedStates = controller.observeFeature(denied, feature)

		expect(AccessStateUtils.isAllowed(allowedStates:GetLastValue())).toEqual(true)
		expect(AccessStateUtils.isAllowed(deniedStates:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessDataService.PromiseFeature", function()
	it("stays pending while the verdict is unresolved", function()
		local controller = setup()
		controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local promise =
			controller.maid:GivePromise(controller.accessDataService:PromiseFeature(controller.fakePlayer(), feature))

		expect(promise:IsPending()).toEqual(true)

		controller:Destroy()
	end)

	it("settles once a real verdict arrives", function()
		local controller = setup()
		local ownsGame = controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local promise =
			controller.maid:GivePromise(controller.accessDataService:PromiseFeature(controller.fakePlayer(), feature))
		ownsGame.Value = true

		local state = PromiseTestUtils.awaitFulfilled(promise)
		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessDataService.SetFactOverride", function()
	it("forces a fact the player does not actually have", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("forces unresolved, which is the state hardest to reproduce by hand", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", nil)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("restores the real value when the override is disposed", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		local clear = controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		clear()
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)

	it("does not leak one player's override onto another", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local overridden = controller.fakePlayer()
		local other = controller.fakePlayer()
		controller.accessDataService:SetFactOverride(overridden, "ownsChapterPass", true)

		local otherStates = controller.observeFeature(other, feature)

		expect(AccessStateUtils.isAllowed(otherStates:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)

	it("refuses a fact nobody registered, so a typo is loud", function()
		local controller = setup()

		expect(function()
			controller.accessDataService:SetFactOverride(controller.fakePlayer(), "onwsGame", true)
		end).toThrow("No fact registered")

		controller:Destroy()
	end)

	it("clears every override for a player at once", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		controller.accessDataService:ClearFactOverrides(player)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessDataService.ObserveFactReport", function()
	it("names the layer that decided", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true, { source = "purchase" })

		local report = controller.observeFactReport(controller.fakePlayer(), "ownsChapterPass"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("purchase")

		controller:Destroy()
	end)

	it("lets the highest-priority layer win", function()
		local controller = setup()
		controller.fact("isStaff", false, { source = "groupRank" })
		controller.fact("isStaff", true, { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.observeFactReport(controller.fakePlayer(), "isStaff"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("allowlist")

		controller:Destroy()
	end)

	it("falls through a layer that abstains", function()
		local controller = setup()
		controller.fact("isStaff", true, { source = "groupRank" })
		controller.abstainingFact("isStaff", { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.observeFactReport(controller.fakePlayer(), "isStaff"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("groupRank")

		controller:Destroy()
	end)

	it("falls through a layer that answers unresolved to one that knows", function()
		local controller = setup()
		controller.fact("isStaff", true, { source = "groupRank" })
		controller.fact("isStaff", nil, { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.observeFactReport(controller.fakePlayer(), "isStaff"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("groupRank")

		controller:Destroy()
	end)

	it("lists every layer, highest priority first, with the losers still visible", function()
		local controller = setup()
		controller.fact("isStaff", false, { source = "groupRank" })
		controller.fact("isStaff", true, { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		local report = controller.observeFactReport(controller.fakePlayer(), "isStaff"):GetLastValue()

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

		controller:Destroy()
	end)

	it("shows an override as its own layer with the real answer still underneath", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false, { source = "purchase" })

		local player = controller.fakePlayer()
		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)

		local report = controller.observeFactReport(player, "ownsChapterPass"):GetLastValue()

		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("override")
		expect(report.layers[2].source).toEqual("purchase")
		expect(report.layers[2].value).toEqual(false)

		controller:Destroy()
	end)

	it("is unresolved with no decider when every layer abstains", function()
		local controller = setup()
		controller.abstainingFact("isStaff", { priority = AccessFactPriority.DEFAULT, source = "groupRank" })

		local report = controller.observeFactReport(controller.fakePlayer(), "isStaff"):GetLastValue()

		expect(report.value).toEqual(nil)
		expect(report.decidedBy).toEqual(nil)

		controller:Destroy()
	end)
end)

describe("AccessDataService.ObserveFeatureReport", function()
	it("returns the verdict together with the facts it was reached from", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false, { source = "purchase" })
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local reports = controller.maid:Add(
			ObservableSpy.new(controller.accessDataService:ObserveFeatureReport(controller.fakePlayer(), feature))
		)
		local report = reports:GetLastValue()

		expect(report.featureName).toEqual("chapters")
		expect(AccessStateUtils.isAllowed(report.state)).toEqual(false)
		expect(report.facts.ownsChapterPass.decidedBy).toEqual("purchase")
		expect(report.facts.ownsChapterPass.value).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessDataService.TeardownPlayer", function()
	it("rejects a promise still waiting on a verdict", function()
		local controller = setup()
		controller.fact("ownsChapterPass", nil)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local promise = controller.maid:GivePromise(controller.accessDataService:PromiseFeature(player, feature))
		expect(promise:IsPending()).toEqual(true)

		controller.accessDataService:TeardownPlayer(player)

		expect(promise:IsRejected()).toEqual(true)

		controller:Destroy()
	end)

	it("leaves a promise that already settled alone", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local promise = controller.maid:GivePromise(controller.accessDataService:PromiseFeature(player, feature))
		PromiseTestUtils.awaitFulfilled(promise)

		controller.accessDataService:TeardownPlayer(player)

		expect(promise:IsFulfilled()).toEqual(true)

		controller:Destroy()
	end)

	it("completes a live feature subscription", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		expect(states:IsComplete()).toEqual(false)
		controller.accessDataService:TeardownPlayer(player)
		expect(states:IsComplete()).toEqual(true)

		controller:Destroy()
	end)

	it("completes rather than hanging for a player who already left", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)
		local feature = controller.feature("chapters", { "ownsChapterPass" })

		local player = controller.fakePlayer()
		controller.accessDataService:TeardownPlayer(player)

		local states = controller.observeFeature(player, feature)

		expect(states:IsComplete()).toEqual(true)

		controller:Destroy()
	end)

	it("drops the player's overrides", function()
		local controller = setup()
		controller.fact("ownsChapterPass", false)

		local player = controller.fakePlayer()
		controller.accessDataService:SetFactOverride(player, "ownsChapterPass", true)
		controller.accessDataService:TeardownPlayer(player)

		expect(controller.accessDataService:ObserveIsPlayerPresent(player)).never.toEqual(nil)

		controller:Destroy()
	end)

	it("drops every fact layer's cached resolution for that player", function()
		local controller = setup()
		controller.fact("ownsChapterPass", true)

		local player = controller.fakePlayer()
		controller.observeFactReport(player, "ownsChapterPass")

		controller.accessDataService:TeardownPlayer(player)

		for _, layer in controller.accessDataService:GetFactLayers("ownsChapterPass") do
			expect((layer :: any)._observableByPlayer[player]).toEqual(nil)
		end

		controller:Destroy()
	end)
end)

describe("AccessDataService.ObserveIsPlayerPresent", function()
	it("reports a player as here until they are torn down", function()
		local controller = setup()
		local player = controller.fakePlayer()

		local presence =
			controller.maid:Add(ObservableSpy.new(controller.accessDataService:ObserveIsPlayerPresent(player)))

		expect(presence:GetLastValue()).toEqual(true)
		controller.accessDataService:TeardownPlayer(player)
		expect(presence:GetLastValue()).toEqual(false)

		controller:Destroy()
	end)
end)
