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

	return {
		maid = maid,
		accessDataService = accessDataService,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		localFact = function(factName: string, initial: boolean?, behavior: string?)
			local valueObject = maid:Add(ValueObject.new(initial)) :: any
			maid:GiveTask(accessDataService:RegisterFact(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
				serverOverrideBehavior = behavior,
			})))
			return valueObject
		end,
		report = function(player: Player, factName: string): any
			local last = nil
			maid:GiveTask(accessDataService:ObserveFactReport(player, factName):Subscribe(function(value)
				last = value
			end))
			return last
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
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

		controller:destroy()
	end)

	it("keeps the local answer visible alongside the server one", function()
		local controller = setup()
		controller.localFact("ownsGame", false)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", true)

		local report = controller.report(player, "ownsGame")
		expect(report.localValue).toEqual(false)
		expect(report.serverValue).toEqual(true)
		expect(report.value).toEqual(true)
		expect(report.serverOverrode).toEqual(true)
		expect(report.decidedBy).toEqual("server")

		controller:destroy()
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

		controller:destroy()
	end)

	it("cannot take access away under the default behavior", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", false)

		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller:destroy()
	end)

	it("takes access away when the fact asks for it", function()
		local controller = setup()
		controller.localFact("notBanned", true, ON_DISALLOW)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "notBanned", false)

		expect(controller.report(player, "notBanned").value).toEqual(false)

		controller:destroy()
	end)

	it("reaches the feature that reads the fact", function()
		local controller = setup()
		controller.localFact("serverOnly", nil)

		local feature = AccessFeature.anyOf("chapters", { "serverOnly" })
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "serverOnly", true)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("keeps one player's replicated answer off another", function()
		local controller = setup()
		controller.localFact("serverOnly", nil)

		local told = controller.fakePlayer()
		local other = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(told, "serverOnly", true)

		expect(controller.report(told, "serverOnly").value).toEqual(true)
		expect(controller.report(other, "serverOnly").value).toEqual(nil)

		controller:destroy()
	end)
end)

describe("facts the client cannot compute at all", function()
	it("settles on a server denial instead of hanging forever", function()
		-- The failure this guards is not a wrong answer, it is a screen that never fills in: a receipt
		-- lives in a server-only DataStore, so the client resolver has nothing to read, and under a
		-- behavior that only lets allows through a denial would never arrive.
		local controller = setup()
		controller.localFact("entitled", nil)

		local feature = AccessFeature.anyOf("chapter2", { "entitled" })
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

		controller:destroy()
	end)

	it("resolves a fact that is not registered on this realm at all", function()
		-- A client cannot register a resolver for something it has no way to read, so the fact exists
		-- here only as a replicated value.
		local controller = setup()

		local feature = AccessFeature.anyOf("chapter2", { "serverOnlyEntitlement" })
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(controller.accessDataService:ObserveFeature(player, feature):Subscribe(function(state)
			last = state
		end))

		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "serverOnlyEntitlement", true)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("still lets a local answer stand where there is one", function()
		-- Rule 2 must not become "the server always wins": a fact this realm can answer keeps its
		-- behavior.
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", false)

		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller:destroy()
	end)
end)
