--!strict
--[[
	Fact replication and the four ways a server answer may combine with a locally-resolved one.

	The wire itself is not exercised here -- a headless test place has one realm and no client to receive
	on -- so the transport is tested at its seam: the server side is driven to send, and the client side's
	entry point, `SetServerFactValue`, is driven directly. The combining rules, which is where the
	behaviour anyone can get wrong lives, are tested exhaustively as pure functions.

	@class AccessReplication.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessReplicationState = require("AccessReplicationState")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local ALL = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ALL
local NONE = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_NONE
local ON_ALLOW = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_ALLOW_ONLY
local ON_DISALLOW = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ON_DISALLOW_ONLY

local combine = AccessFactServerOverrideBehavior.combine

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local controller = {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		localFact = function(factName: string, initial: boolean?, behavior: string?)
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
				serverOverrideBehavior = behavior,
			}))))
			return valueObject
		end,
		report = function(player: Player, factName: string): any
			local last = nil
			maid:GiveTask(accessDataService:ObserveFactReport(player, factName):Subscribe(function(value)
				last = value
			end))
			return last
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessFactServerOverrideBehavior.combine", function()
	it("leaves the local answer alone until the server has actually said something", function()
		-- NOT_YET_ARRIVED and ABSTAINED both mean silence, and neither is a denial. Confusing either with
		-- "arrived saying no" is what would make a client worse off for having replication at all.
		for _, behavior in { ALL, NONE, ON_ALLOW, ON_DISALLOW } do
			expect(combine(true, nil, AccessReplicationState.NOT_YET_ARRIVED, behavior)).toEqual(true)
			expect(combine(false, nil, AccessReplicationState.NOT_YET_ARRIVED, behavior)).toEqual(false)
			expect(combine(true, false, AccessReplicationState.ABSTAINED, behavior)).toEqual(true)
		end
	end)

	it("settles a realm that has no answer of its own, whatever the behavior", function()
		-- The gap this closes: a fact the client cannot compute has no local answer to protect, so the
		-- server's answer is simply the answer. Without this it hangs unresolved forever.
		for _, behavior in { ALL, NONE, ON_ALLOW, ON_DISALLOW } do
			expect(combine(nil, false, AccessReplicationState.RESOLVED, behavior)).toEqual(false)
			expect(combine(nil, true, AccessReplicationState.RESOLVED, behavior)).toEqual(true)
		end
	end)

	it("lets the server decide outright under SERVER_OVERRIDE_ALL", function()
		expect(combine(true, false, AccessReplicationState.RESOLVED, ALL)).toEqual(false)
		expect(combine(false, true, AccessReplicationState.RESOLVED, ALL)).toEqual(true)
	end)

	it("leaves the local answer alone under SERVER_OVERRIDE_NONE", function()
		expect(combine(true, false, AccessReplicationState.RESOLVED, NONE)).toEqual(true)
		expect(combine(false, true, AccessReplicationState.RESOLVED, NONE)).toEqual(false)
	end)

	it("only ever opens under SERVER_OVERRIDE_ON_ALLOW_ONLY", function()
		expect(combine(false, true, AccessReplicationState.RESOLVED, ON_ALLOW)).toEqual(true)
		-- and never closes
		expect(combine(true, false, AccessReplicationState.RESOLVED, ON_ALLOW)).toEqual(true)
	end)

	it("only ever closes under SERVER_OVERRIDE_ON_DISALLOW_ONLY", function()
		expect(combine(true, false, AccessReplicationState.RESOLVED, ON_DISALLOW)).toEqual(false)
		-- and never opens
		expect(combine(false, true, AccessReplicationState.RESOLVED, ON_DISALLOW)).toEqual(false)
	end)

	it("treats a server that answered unresolved as an answer", function()
		-- UNRESOLVED is the server saying "nobody knows", which stops a local fall-through -- that is how
		-- a console override forces a fact to unresolved.
		expect(combine(true, nil, AccessReplicationState.UNRESOLVED, ALL)).toEqual(nil)
	end)

	it("defaults to allow-only, so replication can never take a local answer away", function()
		expect(combine(false, true, AccessReplicationState.RESOLVED, nil)).toEqual(true)
		expect(combine(true, false, AccessReplicationState.RESOLVED, nil)).toEqual(true)
		expect(AccessFactServerOverrideBehavior.DEFAULT).toEqual(ON_ALLOW)
	end)

	it("refuses a behavior it does not know rather than guessing", function()
		expect(function()
			combine(true, false, AccessReplicationState.RESOLVED, "whateverSeemsRight")
		end).toThrow("Unknown behavior")
	end)
end)

describe("AccessDataService.SetServerFactValue", function()
	it("turns a locally-unresolvable fact into a real answer", function()
		-- The motivating case: the client cannot see the mechanism, so it reads unresolved until the
		-- server says otherwise.
		local controller = setup()
		controller.localFact("serverOnly", nil)

		local player = controller.fakePlayer()
		expect(controller.report(player, "serverOnly").value).toEqual(nil)

		controller.accessDataService:SetServerFactValue(player, "serverOnly", true)

		expect(controller.report(player, "serverOnly").value).toEqual(true)

		controller:Destroy()
	end)

	it("keeps the local answer visible alongside the server one", function()
		local controller = setup()
		controller.localFact("ownsGame", false)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", true)

		-- The local answer is not a separate field any more: it is a layer, visible in the readout under
		-- the replicated one that outranked it.
		local report = controller.report(player, "ownsGame")
		expect(report.serverValue).toEqual(true)
		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("replicated")

		local localLayer = nil
		for _, layer in report.layers do
			if layer.source == "default" then
				localLayer = layer
			end
		end
		expect((localLayer :: any).value).toEqual(false)

		controller:Destroy()
	end)

	it("does not override under SERVER_OVERRIDE_NONE, but still reports what the server said", function()
		-- Replication always happens; only the overriding is configurable.
		local controller = setup()
		controller.localFact("clientKnows", false, NONE)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "clientKnows", true)

		local report = controller.report(player, "clientKnows")
		expect(report.value).toEqual(false)
		expect(report.serverValue).toEqual(true)
		expect(report.serverOverrode).toEqual(false)

		controller:Destroy()
	end)

	it("cannot take access away under the default behavior", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", false)

		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller:Destroy()
	end)

	it("takes access away when the fact asks for it", function()
		local controller = setup()
		controller.localFact("notBanned", true, ON_DISALLOW)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "notBanned", false)

		expect(controller.report(player, "notBanned").value).toEqual(false)

		controller:Destroy()
	end)

	it("reaches the feature that reads the fact", function()
		local controller = setup()
		controller.localFact("serverOnly", nil)

		local feature = controller.maid:Add(AccessFeature.anyOf("chapters", { "serverOnly" }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "serverOnly", true)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:Destroy()
	end)

	it("keeps one player's replicated answer off another", function()
		local controller = setup()
		controller.localFact("serverOnly", nil)

		local told = controller.fakePlayer()
		local other = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(told, "serverOnly", true)

		expect(controller.report(told, "serverOnly").value).toEqual(true)
		expect(controller.report(other, "serverOnly").value).toEqual(nil)

		controller:Destroy()
	end)
end)

describe("facts the client cannot compute at all", function()
	it("settles on a server denial instead of hanging forever", function()
		-- The failure this guards is not a wrong answer, it is a screen that never fills in: a receipt
		-- lives in a server-only DataStore, so the client resolver has nothing to read, and under a
		-- behavior that only lets allows through a denial would never arrive.
		local controller = setup()
		controller.localFact("entitled", nil)

		local feature = controller.maid:Add(AccessFeature.anyOf("chapter2", { "entitled" }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "entitled", false)

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(false)
		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(false)

		controller:Destroy()
	end)

	it("resolves a fact that is not registered on this realm at all", function()
		-- A client cannot register a resolver for something it has no way to read, so the fact exists
		-- here only as a replicated value.
		local controller = setup()

		local feature = controller.maid:Add(AccessFeature.anyOf("chapter2", { "serverOnlyEntitlement" }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "serverOnlyEntitlement", true)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:Destroy()
	end)

	it("still lets a local answer stand where there is one", function()
		-- Rule 2 must not become "the server always wins": a fact this realm can answer keeps its
		-- behavior.
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", false)

		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessDataService.SetReplicatedFeatureFactNames", function()
	--[[
		A fact's value replicates per player; which facts a feature reads is game-wide. A game that widens a
		feature only on the server would otherwise leave the client gating on the narrower rule -- the two
		realms reaching different verdicts, which is the failure this package exists to prevent.
	]]
	local function registerFeature(controller: any, featureName: string, factNames: { string })
		local feature = controller.maid:Add(AccessFeature.anyOf(featureName, factNames))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))
		return feature
	end

	it("widens a feature this realm never pushed onto", function()
		local controller = setup()
		local feature = registerFeature(controller, "chapters", { "ownsGame" })

		controller.accessDataService:SetReplicatedFeatureFactNames({
			chapters = { "ownsGame", "gamePass" },
		})

		expect(feature:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		controller:Destroy()
	end)

	it("carries a verdict through the fact it was told about", function()
		-- The point of being told at all: the client has no resolver for the pushed fact, so its answer
		-- can only come from the per-player replication.
		local controller = setup()
		local feature = registerFeature(controller, "chapters", { "ownsGame" })
		controller.localFact("ownsGame", false)

		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame", "gamePass" } })

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "gamePass", true)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:Destroy()
	end)

	it("applies to a feature registered after the payload arrived", function()
		-- Registration order is not ours to control, and either signal may land first.
		local controller = setup()
		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "gamePass" } })

		local feature = registerFeature(controller, "chapters", { "ownsGame" })

		expect(feature:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		controller:Destroy()
	end)

	it("takes back a fact the server stops naming", function()
		local controller = setup()
		local feature = registerFeature(controller, "chapters", { "ownsGame" })

		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame", "gamePass" } })
		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame" } })

		expect(feature:GetFactNames()).toEqual({ "ownsGame" })

		controller:Destroy()
	end)

	it("never takes back a fact this realm pushed itself", function()
		-- Replication widens a feature here, it does not own it. A game that pushed in shared code keeps
		-- its grant whatever the server happens to be saying.
		local controller = setup()
		local feature = registerFeature(controller, "chapters", { "ownsGame" })
		controller.maid:GiveTask(feature:PushFactNameAllowsFeature("staffAllowlist"))

		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame" } })

		expect(feature:GetFactNames()).toEqual({ "ownsGame", "staffAllowlist" })

		controller:Destroy()
	end)

	it("ignores a feature this realm does not have", function()
		local controller = setup()

		expect(function()
			controller.accessDataService:SetReplicatedFeatureFactNames({ neverRegistered = { "gamePass" } })
		end).never.toThrow()

		controller:Destroy()
	end)
end)

describe("replicated feature facts across a feature's lifetime", function()
	it("re-applies to a feature registered again under the same name", function()
		-- The removers are keyed by name but close over the feature object. Left behind, they make the
		-- replacement look already-pushed, and it silently gates on the narrower rule.
		local controller = setup()
		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "gamePass" } })

		local first = controller.maid:Add(AccessFeature.anyOf("chapters", { "ownsGame" }))
		local unregister = controller.accessDataService:RegisterFeature(first)
		expect(first:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		unregister()

		local second = controller.maid:Add(AccessFeature.anyOf("chapters", { "ownsGame" }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(second))

		expect(second:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		controller:Destroy()
	end)
end)

describe("AccessDataService.SetReplicatedFactOverrides", function()
	--[[
		An override is a debugging instruction, not an entitlement. One that took effect in only one realm
		would be the worst of both: the server's gate open while the client still renders it shut, and
		nothing in either readout saying why.
	]]
	it("closes a gate the local answer had opened", function()
		-- The case a replicated *value* cannot reach: under the default behaviour a server false never
		-- overrides a local true, so without this the override simply would not land.
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller.accessDataService:SetReplicatedFactOverrides(player, { ownsGame = { value = false } })

		expect(controller.report(player, "ownsGame").value).toEqual(false)

		controller:Destroy()
	end)

	it("shows up as an override rather than as an unexplained replicated value", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetReplicatedFactOverrides(player, { ownsGame = { value = false } })

		local report = controller.report(player, "ownsGame")
		expect(report.decidedBy).toEqual("override")

		local overrideLayer = nil
		for _, layer in report.layers do
			if layer.source == "override" then
				overrideLayer = layer
			end
		end

		-- Named as the server's, so "I cleared that override and it is still set" is a short conversation.
		expect((overrideLayer :: any).metadata.replicated).toEqual(true)

		controller:Destroy()
	end)

	it("carries a forced-unresolved override, which is a thing people deliberately do", function()
		-- The entry exists with no value. JSON drops nil, so presence is what says an override is set at
		-- all -- otherwise "force this to unresolved" arrives as "no override".
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetReplicatedFactOverrides(player, { ownsGame = {} })

		expect(controller.report(player, "ownsGame").value).toEqual(nil)

		controller:Destroy()
	end)

	it("lets a local override shadow the server's", function()
		-- So somebody investigating in this realm is not fighting a console session left running elsewhere.
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetReplicatedFactOverrides(player, { ownsGame = { value = false } })
		controller.maid:GiveTask(controller.accessDataService:SetFactOverride(player, "ownsGame", true))

		local report = controller.report(player, "ownsGame")
		expect(report.value).toEqual(true)
		expect(report.layers[1].metadata).toEqual(nil)

		controller:Destroy()
	end)

	it("lifts again when the server clears it", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetReplicatedFactOverrides(player, { ownsGame = { value = false } })
		controller.accessDataService:SetReplicatedFactOverrides(player, {})

		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller:Destroy()
	end)

	it("keeps one player's override off another", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local told = controller.fakePlayer()
		local other = controller.fakePlayer()
		controller.accessDataService:SetReplicatedFactOverrides(told, { ownsGame = { value = false } })

		expect(controller.report(told, "ownsGame").value).toEqual(false)
		expect(controller.report(other, "ownsGame").value).toEqual(true)

		controller:Destroy()
	end)
end)
