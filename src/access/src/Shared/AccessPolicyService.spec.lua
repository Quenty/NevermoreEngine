--!strict
--[[
	@class AccessPolicyService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactNames = require("AccessFactNames")
local AccessFactPriority = require("AccessFactPriority")
local AccessFeature = require("AccessFeature")
local AccessKickPolicy = require("AccessKickPolicy")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyNames = require("AccessPolicyNames")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessPolicyService = require("AccessPolicyService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Counter = { count: number }
type KickPolicyOptions = { message: string?, isEnabledByDefault: boolean? }

type Controller = {
	maid: Maid.Maid,
	serviceBag: ServiceBag.ServiceBag,
	accessDataService: AccessDataService.AccessDataService,
	accessPolicyService: AccessPolicyService.AccessPolicyService,
	newPlayer: () -> Player,
	setAdmin: (player: Player, value: boolean?) -> (),
	newPolicy: (options: AccessPolicy.AccessPolicyOptions) -> AccessPolicy.AccessPolicy,
	registerPolicy: (policy: AccessPolicy.AccessPolicy) -> AccessPolicy.AccessPolicy,
	newCountingPolicy: (policyName: string, isEnabledByDefault: boolean?) -> (AccessPolicy.AccessPolicy, Counter),
	registerCountingPolicy: (policyName: string, isEnabledByDefault: boolean?) -> Counter,
	Destroy: (self: Controller) -> (),
}

local function setup(tieRealm: TieRealms.TieRealm?): Controller
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	if tieRealm then
		local tieRealmService: TieRealmService.TieRealmService = serviceBag:GetService(TieRealmService) :: any
		tieRealmService:SetTieRealm(tieRealm)
	end
	local accessDataService: AccessDataService.AccessDataService = serviceBag:GetService(AccessDataService) :: any
	local accessPolicyService: AccessPolicyService.AccessPolicyService =
		serviceBag:GetService(AccessPolicyService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local controller: Controller
	controller = {
		maid = maid,
		serviceBag = serviceBag,
		accessDataService = accessDataService,
		accessPolicyService = accessPolicyService,
		newPlayer = function()
			return maid:Add(PlayerMock.new()) :: any
		end,
		setAdmin = function(player, value)
			accessDataService:SetFactOverride(player, AccessFactNames.PLAYER_IS_ADMIN, value)
		end,
		newPolicy = function(options)
			return maid:Add(AccessPolicy.new(serviceBag, options))
		end,
		registerPolicy = function(policy)
			maid:GiveTask(accessPolicyService:RegisterPolicy(policy))
			return policy
		end,
		newCountingPolicy = function(policyName, isEnabledByDefault)
			local applied: Counter = { count = 0 }
			local policy = controller.newPolicy({
				policyName = policyName,
				isEnabledByDefault = isEnabledByDefault,
				apply = function()
					applied.count += 1

					return function()
						applied.count -= 1
					end
				end,
			})

			return policy, applied
		end,
		registerCountingPolicy = function(policyName, isEnabledByDefault)
			local policy, applied = controller.newCountingPolicy(policyName, isEnabledByDefault)
			controller.registerPolicy(policy)
			return applied
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("AccessPolicyService.RegisterPolicy", function()
	it("registers disabled, so shipping a policy does not switch it on", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop")
		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(false)
		expect(applied.count).toEqual(0)

		controller:Destroy()
	end)

	it("registers a policy that asked to be on already running", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop", true)
		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(true)
		expect(applied.count).toEqual(1)

		controller:Destroy()
	end)

	it("applies a default-enabled policy to players already here", function()
		local controller = setup()
		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		local applied = controller.registerCountingPolicy("noop", true)

		expect(applied.count).toEqual(1)

		controller:Destroy()
	end)

	it("lets the console turn a default-enabled policy back off", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop", true)
		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		controller.accessPolicyService:SetPolicyEnabled("noop", false)

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(false)
		expect(applied.count).toEqual(0)

		controller:Destroy()
	end)

	it("ships the built-in kick policy off, whatever this option allows", function()
		local controller = setup()

		expect(controller.accessPolicyService:IsPolicyEnabled(AccessPolicyNames.KICK_ON_NON_ADMIN)).toEqual(false)

		controller:Destroy()
	end)

	it("lists a disabled policy anyway, so it can be discovered", function()
		local controller = setup()
		controller.registerCountingPolicy("noop")

		expect(controller.accessPolicyService:GetPolicyNames()).toEqual({ AccessPolicyNames.KICK_ON_NON_ADMIN, "noop" })

		controller:Destroy()
	end)

	it("refuses two policies under one name", function()
		local controller = setup()
		controller.registerCountingPolicy("noop")
		local duplicate = controller.newCountingPolicy("noop")

		expect(function()
			controller.accessPolicyService:RegisterPolicy(duplicate)
		end).toThrow("already registered")

		controller:Destroy()
	end)

	it("refuses to enable a policy nobody registered", function()
		local controller = setup()

		expect(function()
			controller.accessPolicyService:SetPolicyEnabled("nosuch", true)
		end).toThrow("No policy registered")

		controller:Destroy()
	end)
end)

describe("AccessPolicyService.SetPolicyEnabled", function()
	it("applies to players already here when switched on", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop")
		controller.accessPolicyService:AddPlayer(controller.newPlayer())
		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(applied.count).toEqual(2)

		controller:Destroy()
	end)

	it("applies to a player who arrives while it is on", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop")
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		expect(applied.count).toEqual(1)

		controller:Destroy()
	end)

	it("tears down when switched off", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop")
		controller.accessPolicyService:AddPlayer(controller.newPlayer())
		controller.accessPolicyService:SetPolicyEnabled("noop", true)
		expect(applied.count).toEqual(1)

		controller.accessPolicyService:SetPolicyEnabled("noop", false)

		expect(applied.count).toEqual(0)

		controller:Destroy()
	end)

	it("tears down when the player leaves", function()
		local controller = setup()
		local applied = controller.registerCountingPolicy("noop")
		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		controller.accessPolicyService:RemovePlayer(player)

		expect(applied.count).toEqual(0)

		controller:Destroy()
	end)

	it("leaves the other policies alone when one is switched off", function()
		local controller = setup()
		local a = controller.registerCountingPolicy("a")
		local b = controller.registerCountingPolicy("b")
		controller.accessPolicyService:AddPlayer(controller.newPlayer())
		controller.accessPolicyService:SetPolicyEnabled("a", true)
		controller.accessPolicyService:SetPolicyEnabled("b", true)

		controller.accessPolicyService:SetPolicyEnabled("a", false)

		expect(a.count).toEqual(0)
		expect(b.count).toEqual(1)

		controller:Destroy()
	end)
end)

describe("AccessPolicy declarations", function()
	it("refuses a policy reading a fact it did not declare", function()
		local controller = setup()
		controller.registerPolicy(controller.newPolicy({
			policyName = "sneaky",
			apply = function(context)
				return context.observeFact(AccessFactNames.PLAYER_IS_ADMIN):Subscribe(function() end)
			end,
		}))
		controller.accessPolicyService:AddPlayer(controller.newPlayer())

		expect(function()
			controller.accessPolicyService:SetPolicyEnabled("sneaky", true)
		end).toThrow("without declaring it")

		controller:Destroy()
	end)
end)

describe("AccessKickPolicy.whenFactIs", function()
	local POLICY_NAME = "kick-on-non-admin-test"

	local function registerKickPolicy(controller: Controller, options: KickPolicyOptions?)
		controller.registerPolicy(
			controller.maid:Add(
				AccessKickPolicy.whenFactIs(
					controller.serviceBag,
					POLICY_NAME,
					AccessFactNames.PLAYER_IS_ADMIN,
					false,
					options
				)
			)
		)
	end

	local function armKickPolicy(controller: Controller, options: KickPolicyOptions?)
		registerKickPolicy(controller, options)
		controller.accessPolicyService:SetPolicyEnabled(POLICY_NAME, true)
	end

	it("does not kick while the fact is unresolved", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, nil)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:Destroy()
	end)

	it("does not kick when the fact reads the other way", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, true)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:Destroy()
	end)

	it("kicks when the fact reads the bound value", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).never.toEqual(nil)

		controller:Destroy()
	end)

	it("kicks when someone is demoted mid-session", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, true)
		controller.accessPolicyService:AddPlayer(player)
		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller.setAdmin(player, false)

		expect(PlayerMock.getKickMessage(player)).never.toEqual(nil)

		controller:Destroy()
	end)

	it("does not kick while it is disabled, however the fact reads", function()
		local controller = setup()
		registerKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:Destroy()
	end)

	it("uses the message it was bound with", function()
		local controller = setup()
		armKickPolicy(controller, { message = "staff only" })

		local player = controller.newPlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual("staff only")

		controller:Destroy()
	end)

	it("is outranked by a game's own layer of the same fact", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessDataService:RegisterFact(
				controller.maid:Add(AccessFact.new(AccessFactNames.PLAYER_IS_ADMIN, {
					resolve = function()
						return true
					end,
					priority = AccessFactPriority.ELEVATED,
					source = "gameAllowlist",
				}))
			)
		)
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:Destroy()
	end)

	it("declares the fact it was bound to, so a readout can name it", function()
		local controller = setup()
		armKickPolicy(controller)

		local policy = controller.accessPolicyService:GetPolicy(POLICY_NAME) :: AccessPolicy.AccessPolicy

		expect(policy:GetFactNames()).toEqual({ AccessFactNames.PLAYER_IS_ADMIN })

		controller:Destroy()
	end)
end)

describe("AccessKickPolicy.whenFeatureDisallowed", function()
	local POLICY_NAME = "kick-without-access"

	local function armKickPolicy(controller: Controller)
		local feature = controller.maid:Add(AccessFeature.anyOf("chapters", { AccessFactNames.PLAYER_IS_ADMIN }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(feature))

		controller.registerPolicy(
			controller.maid:Add(AccessKickPolicy.whenFeatureDisallowed(controller.serviceBag, POLICY_NAME, feature))
		)
		controller.accessPolicyService:SetPolicyEnabled(POLICY_NAME, true)
	end

	it("does not kick while the verdict is unresolved", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, nil)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:Destroy()
	end)

	it("does not kick an allowed player", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, true)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:Destroy()
	end)

	it("kicks a player the feature refuses for a real reason", function()
		local controller = setup()
		armKickPolicy(controller)

		local player = controller.newPlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).never.toEqual(nil)

		controller:Destroy()
	end)

	it("declares the feature it was bound to", function()
		local controller = setup()
		armKickPolicy(controller)

		local policy = controller.accessPolicyService:GetPolicy(POLICY_NAME) :: AccessPolicy.AccessPolicy

		expect(#policy:GetFeatures()).toEqual(1)

		controller:Destroy()
	end)
end)

describe("AccessPolicyService query API", function()
	it("tracks a policy being switched on and off, live", function()
		local controller = setup()
		controller.registerCountingPolicy("noop")

		local isEnabled =
			controller.maid:Add(ObservableSpy.new(controller.accessPolicyService:ObserveIsPolicyEnabled("noop")))

		expect(isEnabled:GetLastValue()).toEqual(false)

		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(isEnabled:GetLastValue()).toEqual(true)

		controller.accessPolicyService:SetPolicyEnabled("noop", false)

		expect(isEnabled:GetLastValue()).toEqual(false)

		controller:Destroy()
	end)

	it("reports false for a policy nobody registered rather than erroring", function()
		local controller = setup()

		local isEnabled =
			controller.maid:Add(ObservableSpy.new(controller.accessPolicyService:ObserveIsPolicyEnabled("nosuch")))

		expect(isEnabled:GetLastValue()).toEqual(false)

		controller:Destroy()
	end)

	it("observes the registry as policies are added", function()
		local controller = setup()

		local policyNames = controller.maid:Add(ObservableSpy.new(controller.accessPolicyService:ObservePolicyNames()))
		local before = #policyNames:GetLastValue()

		controller.registerCountingPolicy("noop")

		expect(#policyNames:GetLastValue()).toEqual(before + 1)

		controller:Destroy()
	end)

	it("answers which policies read a fact", function()
		local controller = setup()

		expect(controller.accessPolicyService:GetPolicyNamesReadingFact(AccessFactNames.PLAYER_IS_ADMIN)).toEqual({
			AccessPolicyNames.KICK_ON_NON_ADMIN,
		})
		expect(controller.accessPolicyService:GetPolicyNamesReadingFact("somethingElse")).toEqual({})

		controller:Destroy()
	end)

	it("answers which policies read a feature", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("shop", {}))

		controller.registerPolicy(controller.newPolicy({
			policyName = "watchShop",
			features = { feature },
			apply = function()
				return nil
			end,
		}))

		expect(controller.accessPolicyService:GetPolicyNamesReadingFeature(feature)).toEqual({ "watchShop" })

		controller:Destroy()
	end)
end)

describe("AccessPolicyService.IsPolicyActiveForPlayer", function()
	it("is false while the policy is enabled but the player is not tracked", function()
		local controller = setup()
		controller.registerCountingPolicy("noop")
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		local player = controller.newPlayer()

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(true)
		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "noop")).toEqual(false)

		controller.accessPolicyService:AddPlayer(player)

		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "noop")).toEqual(true)

		controller:Destroy()
	end)

	it("is false for a policy that belongs to the other realm", function()
		local controller = setup()
		controller.registerPolicy(controller.newPolicy({
			policyName = "clientOnly",
			realm = AccessPolicyRealm.CLIENT,
			apply = function()
				return nil
			end,
		}))
		controller.accessPolicyService:SetPolicyEnabled("clientOnly", true)

		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "clientOnly")).toEqual(false)

		controller:Destroy()
	end)

	it("runs a client-realm policy in a bag that was told it is a client", function()
		local controller = setup(TieRealms.CLIENT)
		local applied: Counter = { count = 0 }
		controller.registerPolicy(controller.newPolicy({
			policyName = "clientOnly",
			realm = AccessPolicyRealm.CLIENT,
			isEnabledByDefault = true,
			apply = function()
				applied.count += 1

				return function()
					applied.count -= 1
				end
			end,
		}))

		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(applied.count).toEqual(1)
		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "clientOnly")).toEqual(true)

		controller:Destroy()
	end)

	it("still refuses a server-realm policy in a bag that was told it is a client", function()
		local controller = setup(TieRealms.CLIENT)
		local applied: Counter = { count = 0 }
		controller.registerPolicy(controller.newPolicy({
			policyName = "serverOnly",
			realm = AccessPolicyRealm.SERVER,
			isEnabledByDefault = true,
			apply = function()
				applied.count += 1

				return nil
			end,
		}))

		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(applied.count).toEqual(0)
		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "serverOnly")).toEqual(false)

		controller:Destroy()
	end)

	it("is false for a policy nobody registered", function()
		local controller = setup()
		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "nosuch")).toEqual(false)

		controller:Destroy()
	end)
end)

describe("AccessPolicyService per-player policy queries", function()
	it("is false while the policy is on but this player is not tracked", function()
		local controller = setup()
		controller.registerCountingPolicy("noop")
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		local player = controller.newPlayer()
		local isActive = controller.maid:Add(
			ObservableSpy.new(controller.accessPolicyService:ObserveIsPolicyActiveForPlayer(player, "noop"))
		)

		expect(isActive:GetLastValue()).toEqual(false)

		controller.accessPolicyService:AddPlayer(player)

		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "noop")).toEqual(true)

		controller:Destroy()
	end)

	it("settles only once the policy is actually running for the player", function()
		local controller = setup()
		controller.registerCountingPolicy("noop")

		local player = controller.newPlayer()
		controller.accessPolicyService:AddPlayer(player)

		local promise =
			controller.maid:GivePromise(controller.accessPolicyService:PromiseIsPolicyActiveForPlayer(player, "noop"))
		expect(promise:IsPending()).toEqual(true)

		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(PromiseTestUtils.awaitFulfilled(promise)).toEqual(true)

		controller:Destroy()
	end)
end)

describe("AccessPolicy self-query through the tie", function()
	it("answers without holding a service, and says no for a player nobody is tracking", function()
		local controller = setup()
		local policy = controller.newCountingPolicy("noop")
		controller.registerPolicy(policy)
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(policy:IsPolicyActiveForPlayer(controller.newPlayer())).toEqual(false)

		controller:Destroy()
	end)

	it("says no for a policy no service has ever heard of", function()
		local controller = setup()
		local policy = controller.newCountingPolicy("orphan")

		expect(policy:IsPolicyActiveForPlayer(controller.newPlayer())).toEqual(false)

		controller:Destroy()
	end)
end)
