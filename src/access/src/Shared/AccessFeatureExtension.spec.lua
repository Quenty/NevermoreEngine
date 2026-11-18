--!strict
--[[
	@class AccessFeatureExtension.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessCommandUtils = require("AccessCommandUtils")
local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	ownsGame: AccessFeature.AccessFeature,
	fakePlayer: () -> Player,
	registerFact: (fact: AccessFact.AccessFact) -> AccessFact.AccessFact,
	registerFeature: (feature: AccessFeature.AccessFeature) -> AccessFeature.AccessFeature,
	pushGrant: (factName: string, initial: boolean?) -> ValueObject.ValueObject<boolean?>,
	observeStates: (
		player: Player,
		feature: AccessFeature.AccessFeature
	) -> ObservableSpy.ObservableSpy<AccessStateUtils.AccessState>,
	observeFeatureReports: (
		player: Player,
		feature: AccessFeature.AccessFeature,
		subject: any?
	) -> ObservableSpy.ObservableSpy<AccessDataService.AccessFeatureReport>,
	observeFactReports: (
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

	local ownsGame = assert(accessDataService:GetFeature(WellKnownAccessFeatureNames.OWNS_GAME), "No owns-game feature")

	local controller: Controller = {
		maid = maid,
		accessDataService = accessDataService,
		ownsGame = ownsGame,
		fakePlayer = function()
			return maid:Add(PlayerMock.new())
		end,
		registerFact = function(fact)
			maid:Add(fact)
			maid:GiveTask(accessDataService:RegisterFact(fact))
			return fact
		end,
		registerFeature = function(feature)
			maid:Add(feature)
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		pushGrant = function(factName, initial)
			local valueObject = maid:Add(ValueObject.new(initial))
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
			}))))
			maid:GiveTask(ownsGame:PushFactAllowsFeature(accessDataService:GetFactLayers(factName)[1]))
			return valueObject
		end,
		observeStates = function(player, feature)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFeature(player, feature)))
		end,
		observeFeatureReports = function(player, feature, subject)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFeatureReport(player, feature, subject)))
		end,
		observeFactReports = function(player, factName)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFactReport(player, factName)))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("the shipped owns-game feature", function()
	it("is registered out of the box", function()
		local controller = setup()

		expect(controller.accessDataService:HasFeature(WellKnownAccessFeatureNames.OWNS_GAME)).toEqual(true)
		expect(controller.accessDataService:HasFact(AccessFactNames.OWNS_GAME)).toEqual(true)

		controller:Destroy()
	end)

	it("reads only the purchase before anything is pushed onto it", function()
		local controller = setup()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:Destroy()
	end)
end)

describe("AccessFeature.PushFactAllowsFeature", function()
	it("widens the feature's declared facts", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", false)
		controller.pushGrant("isStaff", false)

		local names = controller.ownsGame:GetFactNames()
		expect(#names).toEqual(3)
		expect(names).toContain("ownsGamePass")
		expect(names).toContain("isStaff")

		controller:Destroy()
	end)

	it("grants the feature when a pushed fact says yes", function()
		local controller = setup()
		local ownsPass = controller.pushGrant("ownsGamePass", false)

		local states = controller.observeStates(controller.fakePlayer(), controller.ownsGame)
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		ownsPass.Value = true

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("reaches consumers that subscribed before the push", function()
		local controller = setup()

		local states = controller.observeStates(controller.fakePlayer(), controller.ownsGame)

		controller.pushGrant("isStaff", true)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("names every fact that granted, not just the first", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", true)
		controller.pushGrant("isStaff", true)

		local states = controller.observeStates(controller.fakePlayer(), controller.ownsGame)

		expect(#(states:GetLastValue() :: AccessStateUtils.AccessAllowedState).grantedBy).toEqual(2)

		controller:Destroy()
	end)

	it("only widens -- a pushed fact reading false cannot deny what another granted", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", true)
		controller.pushGrant("isStaff", false)

		local states = controller.observeStates(controller.fakePlayer(), controller.ownsGame)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("narrows again when the push is disposed", function()
		local controller = setup()
		local valueObject = controller.maid:Add(ValueObject.new(true :: boolean?))
		controller.registerFact(AccessFact.new("ownsGamePass", {
			resolve = function()
				return valueObject
			end,
		}))

		local remove =
			controller.ownsGame:PushFactAllowsFeature(controller.accessDataService:GetFactLayers("ownsGamePass")[1])

		local states = controller.observeStates(controller.fakePlayer(), controller.ownsGame)
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		remove()

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)
		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:Destroy()
	end)

	it("ignores a push of a fact the feature already reads", function()
		local controller = setup()

		local remove = controller.ownsGame:PushFactAllowsFeature(
			controller.accessDataService:GetFactLayers(AccessFactNames.OWNS_GAME)[1]
		)
		remove()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:Destroy()
	end)
end)

describe("declared context in a report", function()
	it("prints the non-fact inputs beside the facts", function()
		local controller = setup()

		local owned = controller.maid:Add(ValueObject.new(true))
		controller.registerFact(AccessFact.new("holdsEgg", {
			resolve = function()
				return owned
			end,
		}))

		local feature = controller.registerFeature(AccessFeature.new("eggPurchase", {
			facts = { "holdsEgg" },
			context = {
				hasCollected = function(subject)
					return Rx.of(subject == "blueEgg")
				end,
			},
			observeCompute = function(observeFacts)
				return observeFacts:Pipe({
					Rx.map(function(factState: any)
						return AccessStateUtils.fromFacts(factState, { "holdsEgg" })
					end) :: any,
				}) :: any
			end,
		}))

		local reports = controller.observeFeatureReports(controller.fakePlayer(), feature, "blueEgg")
		local report = reports:GetLastValue()

		expect(report.context.hasCollected).toEqual(true)
		expect(AccessCommandUtils.formatFeatureReport(report, "blueEgg")).toContain("hasCollected")

		controller:Destroy()
	end)
end)

describe("a feature reading another feature", function()
	local function entitlement(controller: Controller, reason: string?): AccessFeature.AccessFeature
		return controller.registerFeature(AccessFeature.new("chapterEntitlement", {
			facts = {},
			observeCompute = function()
				return Rx.of(
					if reason then AccessStateUtils.disallowed(reason) else AccessStateUtils.allowed({ "ownsGame" })
				) :: any
			end,
		}))
	end

	local function reader(controller: Controller, source: AccessFeature.AccessFeature): AccessFeature.AccessFeature
		return controller.registerFeature(AccessFeature.new("canPlayHere", {
			facts = {},
			features = { source },
			observeCompute = function(_observeFacts, _subject, input)
				return input.observeFeatures:Pipe({
					Rx.map(function(verdicts: any)
						return verdicts.chapterEntitlement
					end) :: any,
				}) :: any
			end,
		}))
	end

	it("keeps the refusal reason instead of collapsing it to a boolean", function()
		local controller = setup()
		local feature = reader(controller, entitlement(controller, "boughtAccessDisabled"))

		local states = controller.observeStates(controller.fakePlayer(), feature)

		expect(states:GetLastValue()).toEqual(AccessStateUtils.disallowed("boughtAccessDisabled"))

		controller:Destroy()
	end)

	it("carries an allowed verdict through with what granted it", function()
		local controller = setup()
		local feature = reader(controller, entitlement(controller, nil))

		local states = controller.observeStates(controller.fakePlayer(), feature)

		expect(states:GetLastValue()).toEqual(AccessStateUtils.allowed({ "ownsGame" }))

		controller:Destroy()
	end)

	it("names the inherited verdict in the report, so the readout can explain it", function()
		local controller = setup()
		local source = entitlement(controller, "boughtAccessDisabled")
		local feature = reader(controller, source)

		expect(feature:GetFeatureInputs()[1]).toEqual(source)

		local reports = controller.observeFeatureReports(controller.fakePlayer(), feature)
		local report = reports:GetLastValue()

		expect((report.features.chapterEntitlement :: any).reason).toEqual("boughtAccessDisabled")

		local text = AccessCommandUtils.formatFeatureReport(report)
		expect(text).toContain("chapterEntitlement")
		expect(text).toContain("boughtAccessDisabled")

		controller:Destroy()
	end)

	it("hands a feature that declared none an empty map rather than nothing", function()
		local controller = setup()
		local seen = nil
		local feature = controller.registerFeature(AccessFeature.new("standalone", {
			facts = {},
			observeCompute = function(_observeFacts, _subject, input)
				return input.observeFeatures:Pipe({
					Rx.map(function(verdicts: any)
						seen = verdicts
						return AccessStateUtils.allowed()
					end) :: any,
				}) :: any
			end,
		}))

		controller.observeStates(controller.fakePlayer(), feature)

		expect(seen).toEqual({})

		controller:Destroy()
	end)

	it("gives the compute the player it is deciding for", function()
		local controller = setup()
		local player = controller.fakePlayer()
		local seen = nil

		local feature = controller.registerFeature(AccessFeature.new("needsPlayer", {
			facts = {},
			observeCompute = function(_observeFacts, _subject, input)
				seen = input.player
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		controller.observeStates(player, feature)

		expect(seen).toEqual(player)

		controller:Destroy()
	end)
end)

describe("push ownership", function()
	it("keeps a fact alive while a second caller still wants it", function()
		local controller = setup()
		local first = controller.ownsGame:PushFactNameAllowsFeature("gamePass")
		local second = controller.ownsGame:PushFactNameAllowsFeature("gamePass")

		first()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME, "gamePass" })

		second()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:Destroy()
	end)
end)

describe("a feature that requires a subject", function()
	it("refuses to be evaluated without one rather than running the compute against nil", function()
		local controller = setup()

		local feature = controller.registerFeature(AccessFeature.new("eggPurchase", {
			facts = {},
			requiresSubject = true,
			observeCompute = function()
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		expect(function()
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature)
		end).toThrow("requires a subject")

		controller:Destroy()
	end)

	it("is fine once it is given one", function()
		local controller = setup()

		local feature = controller.registerFeature(AccessFeature.new("eggPurchase2", {
			facts = {},
			requiresSubject = true,
			observeCompute = function()
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))

		expect(function()
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature, "blueEgg")
		end).never.toThrow()

		controller:Destroy()
	end)
end)

describe("the registered fact-name list", function()
	it("does not re-emit when a layer is added to a fact already present", function()
		local controller = setup()
		local factNames = controller.maid:Add(ObservableSpy.new(controller.accessDataService:ObserveFactNames()))

		local before = #factNames
		controller.registerFact(AccessFact.new(AccessFactNames.OWNS_GAME, {
			resolve = function()
				return nil
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "gameAllowlist",
		}))

		expect(#factNames).toEqual(before)

		controller:Destroy()
	end)

	it("does emit when a genuinely new fact arrives", function()
		local controller = setup()
		local factNames = controller.maid:Add(ObservableSpy.new(controller.accessDataService:ObserveFactNames()))

		local before = #factNames
		controller.registerFact(AccessFact.new("brandNew", {
			resolve = function()
				return nil
			end,
		}))

		expect(#factNames).toBeGreaterThan(before)

		controller:Destroy()
	end)
end)

describe("a registered object that gets destroyed", function()
	it("takes its fact layer out of the registry", function()
		local controller = setup()
		local fact = controller.maid:Add(AccessFact.new("selfDestructing", {
			resolve = function()
				return nil
			end,
		}))
		controller.accessDataService:RegisterFact(fact)
		expect(controller.accessDataService:HasFact("selfDestructing")).toEqual(true)

		fact:Destroy()

		expect(controller.accessDataService:HasFact("selfDestructing")).toEqual(false)

		controller:Destroy()
	end)

	it("leaves a live report readable rather than calling into the wreckage", function()
		local controller = setup()
		local fact = controller.maid:Add(AccessFact.new("selfDestructing2", {
			resolve = function()
				return true
			end,
		}))
		controller.accessDataService:RegisterFact(fact)

		local reports = controller.observeFactReports(controller.fakePlayer(), "selfDestructing2")
		expect(reports:GetLastValue().value).toEqual(true)

		expect(function()
			fact:Destroy()
		end).never.toThrow()

		controller:Destroy()
	end)

	it("takes its feature out of the registry", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("selfDestructingFeature", { "ownsGame" }))
		controller.accessDataService:RegisterFeature(feature)
		expect(controller.accessDataService:GetFeature("selfDestructingFeature")).never.toEqual(nil)

		feature:Destroy()

		expect(controller.accessDataService:GetFeature("selfDestructingFeature")).toEqual(nil)

		controller:Destroy()
	end)

	it("does not mind the disposer being called as well", function()
		local controller = setup()
		local fact = controller.maid:Add(AccessFact.new("selfDestructing3", {
			resolve = function()
				return nil
			end,
		}))
		local unregister = controller.accessDataService:RegisterFact(fact)

		unregister()

		expect(function()
			fact:Destroy()
			unregister()
		end).never.toThrow()

		controller:Destroy()
	end)
end)

describe("a layer destroyed under a live report", function()
	it("stops contributing instead of taking the next merge down with it", function()
		local controller = setup()
		local player = controller.fakePlayer()
		controller.registerFact(AccessFact.new("layered", {
			resolve = function()
				return false
			end,
		}))

		local elevated = controller.maid:Add(AccessFact.new("layered", {
			resolve = function()
				return true
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		}))
		controller.accessDataService:RegisterFact(elevated)

		local reports = controller.observeFactReports(player, "layered")
		expect(reports:GetLastValue().value).toEqual(true)

		elevated:Destroy()

		expect(function()
			controller.maid:GiveTask(controller.accessDataService:SetFactOverride(player, "layered", true))
		end).never.toThrow()

		expect(reports:GetLastValue().value).toEqual(true)

		controller:Destroy()
	end)

	it("takes the destroyed layer out of the readout rather than leaving a dead row", function()
		local controller = setup()
		local player = controller.fakePlayer()
		controller.registerFact(AccessFact.new("layered2", {
			resolve = function()
				return false
			end,
		}))

		local elevated = controller.maid:Add(AccessFact.new("layered2", {
			resolve = function()
				return true
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		}))
		controller.accessDataService:RegisterFact(elevated)

		local reports = controller.observeFactReports(player, "layered2")

		local before = #reports:GetLastValue().layers
		elevated:Destroy()
		controller.maid:GiveTask(controller.accessDataService:SetFactOverride(player, "layered2", nil))

		expect(#reports:GetLastValue().layers).toEqual(before - 1)

		controller:Destroy()
	end)
end)
