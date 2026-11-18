--!strict
--[[
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
local ObservableSpy = require("ObservableSpy")
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

type Controller = {
	maid: Maid.Maid,
	accessDataService: AccessDataService.AccessDataService,
	fakePlayer: () -> Player,
	localFact: (factName: string, initial: boolean?, behavior: string?) -> ValueObject.ValueObject<boolean?>,
	registerFeature: (featureName: string, factNames: { string }) -> AccessFeature.AccessFeature,
	observeFeature: (
		player: Player,
		feature: AccessFeature.AccessFeature
	) -> ObservableSpy.ObservableSpy<AccessStateUtils.AccessState>,
	report: (player: Player, factName: string) -> AccessDataService.AccessFactReport,
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
			return maid:Add(PlayerMock.new())
		end,
		localFact = function(factName, initial, behavior)
			local valueObject = maid:Add(ValueObject.new(initial))
			maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return valueObject
				end,
				serverOverrideBehavior = behavior,
			}))))
			return valueObject
		end,
		registerFeature = function(featureName, factNames)
			local feature = maid:Add(AccessFeature.anyOf(featureName, factNames))
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		observeFeature = function(player, feature)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFeature(player, feature)))
		end,
		report = function(player, factName)
			return maid:Add(ObservableSpy.new(accessDataService:ObserveFactReport(player, factName))):GetLastValue()
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function findLayer(
	report: AccessDataService.AccessFactReport,
	source: string
): AccessDataService.AccessFactLayerReport
	for _, layer in report.layers do
		if layer.source == source then
			return layer
		end
	end

	error(`No {source} layer in the report`)
end

describe("AccessFactServerOverrideBehavior.combine", function()
	it("leaves the local answer alone until the server has actually said something", function()
		for _, behavior in { ALL, NONE, ON_ALLOW, ON_DISALLOW } do
			expect(combine(true, nil, AccessReplicationState.NOT_YET_ARRIVED, behavior)).toEqual(true)
			expect(combine(false, nil, AccessReplicationState.NOT_YET_ARRIVED, behavior)).toEqual(false)
			expect(combine(true, false, AccessReplicationState.ABSTAINED, behavior)).toEqual(true)
		end
	end)

	it("settles a realm that has no answer of its own, whatever the behavior", function()
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
		expect(combine(true, false, AccessReplicationState.RESOLVED, ON_ALLOW)).toEqual(true)
	end)

	it("only ever closes under SERVER_OVERRIDE_ON_DISALLOW_ONLY", function()
		expect(combine(true, false, AccessReplicationState.RESOLVED, ON_DISALLOW)).toEqual(false)
		expect(combine(false, true, AccessReplicationState.RESOLVED, ON_DISALLOW)).toEqual(false)
	end)

	it("treats a server that answered unresolved as an answer", function()
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

		local report = controller.report(player, "ownsGame")
		expect(report.serverValue).toEqual(true)
		expect(report.value).toEqual(true)
		expect(report.decidedBy).toEqual("replicated")
		expect(findLayer(report, "default").value).toEqual(false)

		controller:Destroy()
	end)

	it("does not override under SERVER_OVERRIDE_NONE, but still reports what the server said", function()
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
		local feature = controller.registerFeature("chapters", { "serverOnly" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "serverOnly", true)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

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
		local controller = setup()
		controller.localFact("entitled", nil)
		local feature = controller.registerFeature("chapter2", { "entitled" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "entitled", false)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(false)
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)

	it("resolves a fact that is not registered on this realm at all", function()
		local controller = setup()
		local feature = controller.registerFeature("chapter2", { "serverOnlyEntitlement" })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "serverOnlyEntitlement", true)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("still lets a local answer stand where there is one", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetServerFactValue(player, "ownsGame", false)

		expect(controller.report(player, "ownsGame").value).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessDataService.SetReplicatedFeatureFactNames", function()
	it("widens a feature this realm never pushed onto", function()
		local controller = setup()
		local feature = controller.registerFeature("chapters", { "ownsGame" })

		controller.accessDataService:SetReplicatedFeatureFactNames({
			chapters = { "ownsGame", "gamePass" },
		})

		expect(feature:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		controller:Destroy()
	end)

	it("carries a verdict through the fact it was told about", function()
		local controller = setup()
		local feature = controller.registerFeature("chapters", { "ownsGame" })
		controller.localFact("ownsGame", false)

		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame", "gamePass" } })

		local player = controller.fakePlayer()
		local states = controller.observeFeature(player, feature)

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller.accessDataService:SetServerFactValue(player, "gamePass", true)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("applies to a feature registered after the payload arrived", function()
		local controller = setup()
		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "gamePass" } })

		local feature = controller.registerFeature("chapters", { "ownsGame" })

		expect(feature:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		controller:Destroy()
	end)

	it("takes back a fact the server stops naming", function()
		local controller = setup()
		local feature = controller.registerFeature("chapters", { "ownsGame" })

		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame", "gamePass" } })
		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "ownsGame" } })

		expect(feature:GetFactNames()).toEqual({ "ownsGame" })

		controller:Destroy()
	end)

	it("never takes back a fact this realm pushed itself", function()
		local controller = setup()
		local feature = controller.registerFeature("chapters", { "ownsGame" })
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
		local controller = setup()
		controller.accessDataService:SetReplicatedFeatureFactNames({ chapters = { "gamePass" } })

		local first = controller.maid:Add(AccessFeature.anyOf("chapters", { "ownsGame" }))
		local unregister = controller.accessDataService:RegisterFeature(first)
		expect(first:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		unregister()

		local second = controller.registerFeature("chapters", { "ownsGame" })

		expect(second:GetFactNames()).toEqual({ "ownsGame", "gamePass" })

		controller:Destroy()
	end)
end)

describe("AccessDataService.SetReplicatedFactOverrides", function()
	it("closes a gate the local answer had opened", function()
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
		expect(findLayer(report, "override").metadata).toEqual({ replicated = true })

		controller:Destroy()
	end)

	it("carries a forced-unresolved override, which is a thing people deliberately do", function()
		local controller = setup()
		controller.localFact("ownsGame", true)

		local player = controller.fakePlayer()
		controller.accessDataService:SetReplicatedFactOverrides(player, { ownsGame = {} })

		expect(controller.report(player, "ownsGame").value).toEqual(nil)

		controller:Destroy()
	end)

	it("lets a local override shadow the server's", function()
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
