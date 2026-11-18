--!strict
--[[
	@class AccessDebugState.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyNames = require("AccessPolicyNames")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessPolicyService = require("AccessPolicyService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	maid: Maid.Maid,
	serviceBag: ServiceBag.ServiceBag,
	accessDataService: AccessDataService.AccessDataService,
	accessPolicyService: AccessPolicyService.AccessPolicyService,
	unresolvedFact: (factName: string, options: { priority: number?, source: string? }?) -> AccessFact.AccessFact,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	local accessPolicyService: AccessPolicyService.AccessPolicyService =
		serviceBag:GetService(AccessPolicyService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local controller: Controller = {
		maid = maid,
		serviceBag = serviceBag,
		accessDataService = accessDataService,
		accessPolicyService = accessPolicyService,
		unresolvedFact = function(factName, options)
			return maid:Add(AccessFact.new(factName, {
				resolve = function()
					return nil
				end,
				priority = if options then options.priority else nil,
				source = if options then options.source else nil,
			}))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessFact.GetDebugState", function()
	it("reports the things that decide a merge", function()
		local controller = setup()
		local fact =
			controller.unresolvedFact("isStaff", { priority = AccessFactPriority.ELEVATED, source = "allowlist" })

		expect(fact:GetDebugState()).toEqual({
			factName = "isStaff",
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
			serverOverrideBehavior = AccessFactServerOverrideBehavior.DEFAULT,
		})

		controller:Destroy()
	end)
end)

describe("AccessFeature.GetDebugState", function()
	it("includes facts pushed on after the feature was written", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("shop", { "ownsGame" }))
		controller.maid:GiveTask(feature:PushFactAllowsFeature(controller.unresolvedFact("isStaff")))

		local state = feature:GetDebugState()

		expect(state.featureName).toEqual("shop")
		expect(#state.facts).toEqual(2)

		controller:Destroy()
	end)
end)

describe("AccessPolicy.GetDebugState", function()
	it("says where a policy runs and what it reads", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("shop", {}))
		local policy = controller.maid:Add(AccessPolicy.new(controller.serviceBag, {
			policyName = "closeShop",
			facts = { "isStaff" },
			features = { feature },
			realm = AccessPolicyRealm.CLIENT,
			apply = function()
				return nil
			end,
		}))

		expect(policy:GetDebugState()).toEqual({
			policyName = "closeShop",
			realm = AccessPolicyRealm.CLIENT,
			facts = { "isStaff" },
			features = { "shop" },
			isEnabledByDefault = false,
		})

		controller:Destroy()
	end)
end)

describe("AccessDataService.GetDebugState", function()
	it("lists every layer of every fact, not just the fact names", function()
		local controller = setup()

		local state = controller.accessDataService:GetDebugState()

		expect(#state.facts[AccessFactNames.PLAYER_IS_ADMIN]).toEqual(1)
		expect(state.facts[AccessFactNames.PLAYER_IS_ADMIN][1].source).toEqual("permission")

		controller:Destroy()
	end)

	it("shows a second layer once one is added", function()
		local controller = setup()
		local fact = controller.unresolvedFact(
			AccessFactNames.PLAYER_IS_ADMIN,
			{ priority = AccessFactPriority.ELEVATED, source = "gameAllowlist" }
		)
		controller.maid:GiveTask(controller.accessDataService:RegisterFact(fact))

		local state = controller.accessDataService:GetDebugState()

		expect(#state.facts[AccessFactNames.PLAYER_IS_ADMIN]).toEqual(2)

		controller:Destroy()
	end)

	it("includes the shipped feature and what it reads", function()
		local controller = setup()

		local state = controller.accessDataService:GetDebugState()

		expect(state.features[WellKnownAccessFeatureNames.OWNS_GAME].facts).toEqual({ AccessFactNames.OWNS_GAME })

		controller:Destroy()
	end)
end)

describe("AccessPolicyService.GetDebugState", function()
	it("includes disabled policies, which is most of the answer to why nothing happened", function()
		local controller = setup()

		local state = controller.accessPolicyService:GetDebugState()[AccessPolicyNames.KICK_ON_NON_ADMIN]

		expect(state.enabled).toEqual(false)
		expect(state.realm).toEqual(AccessPolicyRealm.SERVER)
		expect(state.facts).toEqual({ AccessFactNames.PLAYER_IS_ADMIN })

		controller:Destroy()
	end)

	it("tracks a policy being switched on", function()
		local controller = setup()
		controller.accessPolicyService:SetPolicyEnabled(AccessPolicyNames.KICK_ON_NON_ADMIN, true)

		local state = controller.accessPolicyService:GetDebugState()[AccessPolicyNames.KICK_ON_NON_ADMIN]

		expect(state.enabled).toEqual(true)

		controller:Destroy()
	end)
end)
