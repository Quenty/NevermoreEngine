--!strict
--[[
	The extensibility story end-to-end: the package ships `owns-game` reading a purchase, and a game
	unions a gamepass and a staff allowlist on top without editing the feature or replacing it.

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
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local Rx = require("Rx")
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

	local ownsGame = assert(accessDataService:GetFeature(WellKnownAccessFeatureNames.OWNS_GAME), "No owns-game feature")

	return {
		maid = maid,
		accessDataService = accessDataService,
		ownsGame = ownsGame,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		-- Registers a fact the test drives, and pushes it onto owns-game as another way in.
		pushGrant = function(factName: string, initial: boolean?)
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
			}))))
			maid:GiveTask(ownsGame:PushFactAllowsFeature(accessDataService:GetFactLayers(factName)[1]))
			return valueObject
		end,
		observeAllowed = function(player: Player)
			local last = nil
			maid:GiveTask(accessDataService:ObserveFeature(player, ownsGame):Subscribe(function(state)
				last = state
			end))
			return function()
				return last
			end
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("the shipped owns-game feature", function()
	it("is registered out of the box", function()
		local controller = setup()

		expect(controller.accessDataService:HasFeature(WellKnownAccessFeatureNames.OWNS_GAME)).toEqual(true)
		expect(controller.accessDataService:HasFact(AccessFactNames.OWNS_GAME)).toEqual(true)

		controller:destroy()
	end)

	it("reads only the purchase before anything is pushed onto it", function()
		local controller = setup()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)
end)

describe("AccessFeature.PushFactAllowsFeature", function()
	it("widens the feature's declared facts", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", false)
		controller.pushGrant("isStaff", false)

		local names = controller.ownsGame:GetFactNames()
		expect(#names).toEqual(3)
		expect(table.find(names, "ownsGamePass") ~= nil).toEqual(true)
		expect(table.find(names, "isStaff") ~= nil).toEqual(true)

		controller:destroy()
	end)

	it("grants the feature when a pushed fact says yes", function()
		-- The whole point: nobody owns the game, but the gamepass gets them in, and every consumer
		-- already gating on owns-game picks it up without knowing the gamepass exists.
		local controller = setup()
		local ownsPass = controller.pushGrant("ownsGamePass", false)

		local player = controller.fakePlayer()
		local getState = controller.observeAllowed(player)
		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(false)

		ownsPass.Value = true

		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		controller:destroy()
	end)

	it("reaches consumers that subscribed before the push", function()
		-- A push has to reach live subscriptions, or a menu rendered at join never learns about the new
		-- way in.
		local controller = setup()

		local player = controller.fakePlayer()
		local getState = controller.observeAllowed(player)

		controller.pushGrant("isStaff", true)

		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		controller:destroy()
	end)

	it("names every fact that granted, not just the first", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", true)
		controller.pushGrant("isStaff", true)

		local state = controller.observeAllowed(controller.fakePlayer())() :: any

		expect(#state.grantedBy).toEqual(2)

		controller:destroy()
	end)

	it("only widens -- a pushed fact reading false cannot deny what another granted", function()
		local controller = setup()
		controller.pushGrant("ownsGamePass", true)
		controller.pushGrant("isStaff", false)

		local state = controller.observeAllowed(controller.fakePlayer())() :: any

		expect(AccessStateUtils.isAllowed(state)).toEqual(true)

		controller:destroy()
	end)

	it("narrows again when the push is disposed", function()
		local controller = setup()
		local valueObject = controller.maid:Add(ValueObject.new(true :: boolean?)) :: any
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("ownsGamePass", {
				resolve = function()
					return valueObject
				end,
			})))
		)

		local remove =
			controller.ownsGame:PushFactAllowsFeature(controller.accessDataService:GetFactLayers("ownsGamePass")[1])

		local getState = controller.observeAllowed(controller.fakePlayer())
		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(true)

		remove()

		expect(AccessStateUtils.isAllowed(getState() :: any)).toEqual(false)
		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)

	it("ignores a push of a fact the feature already reads", function()
		-- Otherwise the remover handed to the second caller would revoke the first caller's grant.
		local controller = setup()

		local remove = controller.ownsGame:PushFactAllowsFeature(
			controller.accessDataService:GetFactLayers(AccessFactNames.OWNS_GAME)[1]
		)
		remove()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)
end)

describe("declared context in a report", function()
	it("prints the non-fact inputs beside the facts", function()
		-- The whole point of declaring them: a per-thing refusal is explained by the context as often as by
		-- the facts, and before this it was only ever visible inside somebody's closure.
		local controller = setup()

		local owned = controller.maid:Add(ValueObject.new(true)) :: any
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("holdsEgg", {
				resolve = function()
					return owned
				end,
			})))
		)

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
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
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local report = nil
		controller.maid:GiveTask(
			controller.accessDataService
				:ObserveFeatureReport(controller.fakePlayer(), feature, "blueEgg")
				:Subscribe(function(value)
					report = value
				end)
		)

		expect((report :: any).context.hasCollected).toEqual(true)
		expect(string.find(AccessCommandUtils.formatFeatureReport(report, "blueEgg"), "hasCollected") ~= nil).toEqual(
			true
		)

		controller:destroy()
	end)
end)

describe("a feature reading another feature", function()
	--[[
		FeatureAccessFact converts a feature into a *fact*, which collapses the verdict to a boolean and
		drops the reason. A gate that has to tell "bought access is switched off" apart from "does not own
		it" needs the whole state, so it declares the feature and gets the verdict.
	]]
	local function entitlement(controller: any, reason: string?)
		local feature = controller.maid:Add(AccessFeature.new("chapterEntitlement", {
			facts = {},
			observeCompute = function()
				return Rx.of(
					if reason then AccessStateUtils.disallowed(reason) else AccessStateUtils.allowed({ "ownsGame" })
				) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))
		return feature
	end

	local function reader(controller: any, source: any)
		local feature = controller.maid:Add(AccessFeature.new("canPlayHere", {
			facts = {},
			features = { source },
			observeCompute = function(_observeFacts, _subject, input)
				return input.observeFeatures:Pipe({
					Rx.map(function(verdicts: any)
						-- Passed straight through, reason and all. That is the point.
						return verdicts.chapterEntitlement
					end) :: any,
				}) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))
		return feature
	end

	it("keeps the refusal reason instead of collapsing it to a boolean", function()
		local controller = setup()
		local feature = reader(controller, entitlement(controller, "boughtAccessDisabled"))

		local last = nil
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature):Subscribe(function(state)
				last = state
			end)
		)

		expect((last :: any).reason).toEqual("boughtAccessDisabled")

		controller:destroy()
	end)

	it("carries an allowed verdict through with what granted it", function()
		local controller = setup()
		local feature = reader(controller, entitlement(controller, nil))

		local last = nil
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature):Subscribe(function(state)
				last = state
			end)
		)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)
		expect((last :: any).grantedBy).toEqual({ "ownsGame" })

		controller:destroy()
	end)

	it("names the inherited verdict in the report, so the readout can explain it", function()
		local controller = setup()
		local source = entitlement(controller, "boughtAccessDisabled")
		local feature = reader(controller, source)

		expect(feature:GetFeatureInputs()[1]).toEqual(source)

		local report = nil
		controller.maid:GiveTask(
			controller.accessDataService
				:ObserveFeatureReport(controller.fakePlayer(), feature)
				:Subscribe(function(value)
					report = value
				end)
		)

		expect((report :: any).features.chapterEntitlement.reason).toEqual("boughtAccessDisabled")

		local text = AccessCommandUtils.formatFeatureReport(report)
		expect(string.find(text, "chapterEntitlement") ~= nil).toEqual(true)
		expect(string.find(text, "boughtAccessDisabled") ~= nil).toEqual(true)

		controller:destroy()
	end)

	it("hands a feature that declared none an empty map rather than nothing", function()
		-- So a compute can combine it unconditionally instead of stalling forever on a source that never
		-- fires.
		local controller = setup()
		local seen = nil
		local feature = controller.maid:Add(AccessFeature.new("standalone", {
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
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature):Subscribe(function() end)
		)

		expect(seen).toEqual({})

		controller:destroy()
	end)

	it("gives the compute the player it is deciding for", function()
		-- Without this a per-thing feature whose context is also per-player has to smuggle the player
		-- through the subject.
		local controller = setup()
		local player = controller.fakePlayer()
		local seen = nil

		local feature = controller.maid:Add(AccessFeature.new("needsPlayer", {
			facts = {},
			observeCompute = function(_observeFacts, _subject, input)
				seen = input.player
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function() end))

		expect(seen).toEqual(player)

		controller:destroy()
	end)
end)

describe("push ownership", function()
	it("keeps a fact alive while a second caller still wants it", function()
		-- A no-op remover for a repeat push looked harmless and was not: whoever pushed first ended up
		-- owning the name, and their remover took it from everyone.
		local controller = setup()
		local first = controller.ownsGame:PushFactNameAllowsFeature("gamePass")
		local second = controller.ownsGame:PushFactNameAllowsFeature("gamePass")

		first()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME, "gamePass" })

		second()

		expect(controller.ownsGame:GetFactNames()).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)
end)

describe("a feature that requires a subject", function()
	it("refuses to be evaluated without one rather than running the compute against nil", function()
		-- Skipping it in the per-player tracker was never enough on its own: a direct call, a console
		-- command with the argument left off, or a policy all reach the service too.
		local controller = setup()

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase", {
			facts = {},
			requiresSubject = true,
			observeCompute = function()
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		expect(function()
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature)
		end).toThrow("requires a subject")

		controller:destroy()
	end)

	it("is fine once it is given one", function()
		local controller = setup()

		local feature = controller.maid:Add(AccessFeature.new("eggPurchase2", {
			facts = {},
			requiresSubject = true,
			observeCompute = function()
				return Rx.of(AccessStateUtils.allowed()) :: any
			end,
		}))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		expect(function()
			controller.accessDataService:ObserveFeature(controller.fakePlayer(), feature, "blueEgg")
		end).never.toThrow()

		controller:destroy()
	end)
end)

describe("the registered fact-name list", function()
	it("does not re-emit when a layer is added to a fact already present", function()
		-- Anything switchMapping over this drops its shareReplay when it fires, so every resolver for every
		-- player re-runs. A second layer of an existing fact changes no names and must stay quiet.
		local controller = setup()
		local emissions = 0
		controller.maid:GiveTask(controller.accessDataService:ObserveFactNames():Subscribe(function()
			emissions += 1
		end))

		local before = emissions
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new(AccessFactNames.OWNS_GAME, {
				resolve = function()
					return nil
				end,
				priority = AccessFactPriority.ELEVATED,
				source = "gameAllowlist",
			})))
		)

		expect(emissions).toEqual(before)

		controller:destroy()
	end)

	it("does emit when a genuinely new fact arrives", function()
		local controller = setup()
		local emissions = 0
		controller.maid:GiveTask(controller.accessDataService:ObserveFactNames():Subscribe(function()
			emissions += 1
		end))

		local before = emissions
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(controller.maid:Add(AccessFact.new("brandNew", {
				resolve = function()
					return nil
				end,
			})))
		)

		expect(emissions > before).toEqual(true)

		controller:destroy()
	end)
end)

describe("a registered object that gets destroyed", function()
	--[[
		One maid usually holds both the object and its unregister disposer, and DoCleaning runs tasks in no
		particular order. Left registered, a destroyed object is one every reader calls methods on -- and
		BaseObject nils the metatable, so those calls fail rather than returning nothing.
	]]
	it("takes its fact layer out of the registry", function()
		local controller = setup()
		local fact = AccessFact.new("selfDestructing", {
			resolve = function()
				return nil
			end,
		})
		controller.accessDataService:RegisterFact(fact)
		expect(controller.accessDataService:HasFact("selfDestructing")).toEqual(true)

		fact:Destroy()

		expect(controller.accessDataService:HasFact("selfDestructing")).toEqual(false)

		controller:destroy()
	end)

	it("leaves a live report readable rather than calling into the wreckage", function()
		-- The crash this fixes: a merge emission reaches for the layer's override behaviour and finds a
		-- table with no metatable.
		local controller = setup()
		local player = controller.fakePlayer()
		local fact = AccessFact.new("selfDestructing2", {
			resolve = function()
				return true
			end,
		})
		controller.accessDataService:RegisterFact(fact)

		local report = nil
		controller.maid:GiveTask(
			controller.accessDataService:ObserveFactReport(player, "selfDestructing2"):Subscribe(function(value)
				report = value
			end)
		)
		expect((report :: any).value).toEqual(true)

		expect(function()
			fact:Destroy()
		end).never.toThrow()

		controller:destroy()
	end)

	it("takes its feature out of the registry", function()
		local controller = setup()
		local feature = AccessFeature.anyOf("selfDestructingFeature", { "ownsGame" })
		controller.accessDataService:RegisterFeature(feature)
		expect(controller.accessDataService:GetFeature("selfDestructingFeature")).never.toEqual(nil)

		feature:Destroy()

		expect(controller.accessDataService:GetFeature("selfDestructingFeature")).toEqual(nil)

		controller:destroy()
	end)

	it("does not mind the disposer being called as well", function()
		-- The ordinary path still runs it, and both orders have to be fine.
		local controller = setup()
		local fact = AccessFact.new("selfDestructing3", {
			resolve = function()
				return nil
			end,
		})
		local unregister = controller.accessDataService:RegisterFact(fact)

		unregister()

		expect(function()
			fact:Destroy()
			unregister()
		end).never.toThrow()

		controller:destroy()
	end)
end)

describe("a layer destroyed under a live report", function()
	it("stops contributing instead of taking the next merge down with it", function()
		-- The crash this guards is not the destroy itself, it is the *next* emission: a report already
		-- subscribed holds the layer array, and a destroyed BaseObject has no metatable, so every method on
		-- it is missing rather than merely unhelpful. Something always emits afterwards -- an override, a
		-- player leaving, another layer registering.
		local maid = Maid.new()
		local serviceBag = maid:Add(ServiceBag.new())
		local accessDataService: any = serviceBag:GetService(AccessDataService)
		serviceBag:Init()
		serviceBag:Start()

		local player = maid:Add(PlayerMock.new()) :: any
		maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new("layered", {
			resolve = function()
				return false
			end,
		}))))

		-- A second layer, so destroying the first leaves the fact registered and the report alive.
		local elevated = AccessFact.new("layered", {
			resolve = function()
				return true
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})
		accessDataService:RegisterFact(elevated)

		local report = nil
		maid:GiveTask(accessDataService:ObserveFactReport(player, "layered"):Subscribe(function(value)
			report = value
		end))
		expect((report :: any).value).toEqual(true)

		elevated:Destroy()

		-- Forces the merge to run again over the array that layer was in.
		expect(function()
			maid:GiveTask(accessDataService:SetFactOverride(player, "layered", true))
		end).never.toThrow()

		expect((report :: any).value).toEqual(true)

		maid:DoCleaning()
	end)

	it("takes the destroyed layer out of the readout rather than leaving a dead row", function()
		local maid = Maid.new()
		local serviceBag = maid:Add(ServiceBag.new())
		local accessDataService: any = serviceBag:GetService(AccessDataService)
		serviceBag:Init()
		serviceBag:Start()

		local player = maid:Add(PlayerMock.new()) :: any
		maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new("layered2", {
			resolve = function()
				return false
			end,
		}))))

		local elevated = AccessFact.new("layered2", {
			resolve = function()
				return true
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})
		accessDataService:RegisterFact(elevated)

		local report = nil
		maid:GiveTask(accessDataService:ObserveFactReport(player, "layered2"):Subscribe(function(value)
			report = value
		end))

		local before = #(report :: any).layers
		elevated:Destroy()
		maid:GiveTask(accessDataService:SetFactOverride(player, "layered2", nil))

		expect(#(report :: any).layers).toEqual(before - 1)

		maid:DoCleaning()
	end)
end)
