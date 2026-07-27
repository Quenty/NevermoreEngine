--!strict
--[[
	The snapshot APIs. These exist so somebody writing facts, features and policies can print what is
	actually registered instead of inferring it from the code they hoped ran.

	@class AccessDebugState.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyNames = require("AccessPolicyNames")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessPolicyService = require("AccessPolicyService")
local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local WellKnownAccessFeatureNames = require("WellKnownAccessFeatureNames")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	local accessPolicyService: AccessPolicyService.AccessPolicyService =
		serviceBag:GetService(AccessPolicyService) :: any
	serviceBag:Init()
	serviceBag:Start()

	return {
		maid = maid,
		accessDataService = accessDataService,
		accessPolicyService = accessPolicyService,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("AccessFact.GetDebugState", function()
	it("reports the things that decide a merge", function()
		local fact = AccessFact.new("isStaff", {
			resolve = function()
				return nil
			end,
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})

		expect(fact:GetDebugState()).toEqual({
			factName = "isStaff",
			priority = AccessFactPriority.ELEVATED,
			source = "allowlist",
		})
	end)
end)

describe("AccessFeature.GetDebugState", function()
	it("includes facts pushed on after the feature was written", function()
		-- Reading the source of a feature is no longer enough to know what it reads.
		local feature = AccessFeature.anyOf("shop", { "ownsGame" })
		feature:PushFactAllowsFeature(AccessFact.new("isStaff", {
			resolve = function()
				return nil
			end,
		}))

		local state = feature:GetDebugState()
		expect(state.featureName).toEqual("shop")
		expect(#state.facts).toEqual(2)
	end)
end)

describe("AccessPolicy.GetDebugState", function()
	it("says where a policy runs and what it reads", function()
		local feature = AccessFeature.anyOf("shop", {})
		local policy = AccessPolicy.new("closeShop", {
			facts = { "isStaff" },
			features = { feature },
			realm = AccessPolicyRealm.CLIENT,
			apply = function()
				return nil
			end,
		})

		expect(policy:GetDebugState()).toEqual({
			policyName = "closeShop",
			realm = AccessPolicyRealm.CLIENT,
			facts = { "isStaff" },
			features = { "shop" },
		})
	end)
end)

describe("AccessDataService.GetDebugState", function()
	it("lists every layer of every fact, not just the fact names", function()
		local controller = setup()

		local state = controller.accessDataService:GetDebugState()
		expect(#state.facts[AccessFactNames.PLAYER_IS_ADMIN]).toEqual(1)
		expect(state.facts[AccessFactNames.PLAYER_IS_ADMIN][1].source).toEqual("permission")

		controller:destroy()
	end)

	it("shows a second layer once one is added", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(AccessFact.new(AccessFactNames.PLAYER_IS_ADMIN, {
				resolve = function()
					return nil
				end,
				priority = AccessFactPriority.ELEVATED,
				source = "gameAllowlist",
			}))
		)

		local state = controller.accessDataService:GetDebugState()
		expect(#state.facts[AccessFactNames.PLAYER_IS_ADMIN]).toEqual(2)

		controller:destroy()
	end)

	it("includes the shipped feature and what it reads", function()
		local controller = setup()

		local state = controller.accessDataService:GetDebugState()
		expect(state.features[WellKnownAccessFeatureNames.OWNS_GAME].facts).toEqual({ AccessFactNames.OWNS_GAME })

		controller:destroy()
	end)
end)

describe("AccessPolicyService.GetDebugState", function()
	it("includes disabled policies, which is most of the answer to why nothing happened", function()
		local controller = setup()

		local state = controller.accessPolicyService:GetDebugState()
		expect(state[AccessPolicyNames.KICK_ON_NON_ADMIN].enabled).toEqual(false)
		expect(state[AccessPolicyNames.KICK_ON_NON_ADMIN].realm).toEqual(AccessPolicyRealm.SERVER)
		expect(state[AccessPolicyNames.KICK_ON_NON_ADMIN].facts).toEqual({ AccessFactNames.PLAYER_IS_ADMIN })

		controller:destroy()
	end)

	it("tracks a policy being switched on", function()
		local controller = setup()
		controller.accessPolicyService:SetPolicyEnabled(AccessPolicyNames.KICK_ON_NON_ADMIN, true)

		expect(controller.accessPolicyService:GetDebugState()[AccessPolicyNames.KICK_ON_NON_ADMIN].enabled).toEqual(
			true
		)

		controller:destroy()
	end)
end)
