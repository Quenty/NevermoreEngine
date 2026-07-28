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
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

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
		serviceBag = serviceBag,
		accessDataService = accessDataService,
		accessPolicyService = accessPolicyService,
		fakePlayer = function(): Player
			return maid:Add(PlayerMock.new()) :: any
		end,
		-- Overrides the built-in admin fact, which is what an operator does from the console.
		setAdmin = function(player: Player, value: boolean?)
			accessDataService:SetFactOverride(player, AccessFactNames.PLAYER_IS_ADMIN, value)
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

local function countingPolicy(controller: any, policyName: string, applied: { n: number })
	return controller.maid:Add(AccessPolicy.new(controller.serviceBag, {
		policyName = policyName,
		apply = function()
			applied.n += 1

			return function()
				applied.n -= 1
			end
		end,
	}))
end

describe("AccessPolicyService.RegisterPolicy", function()
	it("registers disabled, so shipping a policy does not switch it on", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", applied))
		)
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(false)
		expect(applied.n).toEqual(0)

		controller:destroy()
	end)

	it("lists a disabled policy anyway, so it can be discovered", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)

		expect(controller.accessPolicyService:GetPolicyNames()).toEqual({ AccessPolicyNames.KICK_ON_NON_ADMIN, "noop" })

		controller:destroy()
	end)

	it("refuses two policies under one name", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)

		expect(function()
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		end).toThrow("already registered")

		controller:destroy()
	end)

	it("refuses to enable a policy nobody registered", function()
		local controller = setup()

		expect(function()
			controller.accessPolicyService:SetPolicyEnabled("nosuch", true)
		end).toThrow("No policy registered")

		controller:destroy()
	end)
end)

describe("AccessPolicyService.SetPolicyEnabled", function()
	it("applies to players already here when switched on", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", applied))
		)
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(applied.n).toEqual(2)

		controller:destroy()
	end)

	it("applies to a player who arrives while it is on", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", applied))
		)
		controller.accessPolicyService:SetPolicyEnabled("noop", true)
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		expect(applied.n).toEqual(1)

		controller:destroy()
	end)

	it("tears down when switched off", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", applied))
		)
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())
		controller.accessPolicyService:SetPolicyEnabled("noop", true)
		expect(applied.n).toEqual(1)

		controller.accessPolicyService:SetPolicyEnabled("noop", false)
		expect(applied.n).toEqual(0)

		controller:destroy()
	end)

	it("tears down when the player leaves", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", applied))
		)
		local player = controller.fakePlayer()
		controller.accessPolicyService:AddPlayer(player)
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		controller.accessPolicyService:RemovePlayer(player)

		expect(applied.n).toEqual(0)

		controller:destroy()
	end)

	it("leaves the other policies alone when one is switched off", function()
		local controller = setup()
		local a, b = { n = 0 }, { n = 0 }

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "a", a)))
		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "b", b)))
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())
		controller.accessPolicyService:SetPolicyEnabled("a", true)
		controller.accessPolicyService:SetPolicyEnabled("b", true)

		controller.accessPolicyService:SetPolicyEnabled("a", false)

		expect(a.n).toEqual(0)
		expect(b.n).toEqual(1)

		controller:destroy()
	end)
end)

describe("AccessPolicy declarations", function()
	it("refuses a policy reading a fact it did not declare", function()
		-- The declaration in a readout has to be the whole truth about a policy's inputs.
		local controller = setup()

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(controller.maid:Add(AccessPolicy.new(controller.serviceBag, {
				policyName = "sneaky",
				apply = function(context)
					return context.observeFact(AccessFactNames.PLAYER_IS_ADMIN):Subscribe(function() end)
				end,
			})))
		)
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		expect(function()
			controller.accessPolicyService:SetPolicyEnabled("sneaky", true)
		end).toThrow("without declaring it")

		controller:destroy()
	end)
end)

describe("AccessKickPolicy.whenFactIs", function()
	local POLICY_NAME = "kick-on-non-admin-test"

	local function armed(controller: any)
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(
				controller.maid:Add(
					AccessKickPolicy.whenFactIs(
						controller.serviceBag,
						POLICY_NAME,
						AccessFactNames.PLAYER_IS_ADMIN,
						false
					)
				)
			)
		)
		controller.accessPolicyService:SetPolicyEnabled(POLICY_NAME, true)
	end

	it("does not kick while the fact is unresolved", function()
		-- "We could not find out whether you are staff" is not "you are not staff". Unresolved is not
		-- false, so matching the value exactly gets this right for free.
		local controller = setup()
		armed(controller)

		local player = controller.fakePlayer()
		controller.setAdmin(player, nil)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:destroy()
	end)

	it("does not kick when the fact reads the other way", function()
		local controller = setup()
		armed(controller)

		local player = controller.fakePlayer()
		controller.setAdmin(player, true)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:destroy()
	end)

	it("kicks when the fact reads the bound value", function()
		local controller = setup()
		armed(controller)

		local player = controller.fakePlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).never.toEqual(nil)

		controller:destroy()
	end)

	it("kicks when someone is demoted mid-session", function()
		-- The console flow: enable the policy, drop your own admin fact, get kicked.
		local controller = setup()
		armed(controller)

		local player = controller.fakePlayer()
		controller.setAdmin(player, true)
		controller.accessPolicyService:AddPlayer(player)
		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller.setAdmin(player, false)

		expect(PlayerMock.getKickMessage(player)).never.toEqual(nil)

		controller:destroy()
	end)

	it("does not kick while it is disabled, however the fact reads", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(
				controller.maid:Add(
					AccessKickPolicy.whenFactIs(
						controller.serviceBag,
						POLICY_NAME,
						AccessFactNames.PLAYER_IS_ADMIN,
						false
					)
				)
			)
		)

		local player = controller.fakePlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:destroy()
	end)

	it("uses the message it was bound with", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(
				controller.maid:Add(
					AccessKickPolicy.whenFactIs(
						controller.serviceBag,
						POLICY_NAME,
						AccessFactNames.PLAYER_IS_ADMIN,
						false,
						{
							message = "staff only",
						}
					)
				)
			)
		)
		controller.accessPolicyService:SetPolicyEnabled(POLICY_NAME, true)

		local player = controller.fakePlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual("staff only")

		controller:destroy()
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
		armed(controller)

		local player = controller.fakePlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:destroy()
	end)

	it("declares the fact it was bound to, so a readout can name it", function()
		local controller = setup()
		armed(controller)

		local policy = controller.accessPolicyService:GetPolicy(POLICY_NAME)
		expect((policy :: any):GetFactNames()).toEqual({ AccessFactNames.PLAYER_IS_ADMIN })

		controller:destroy()
	end)
end)

describe("AccessKickPolicy.whenFeatureDisallowed", function()
	local POLICY_NAME = "kick-without-access"

	local function armed(controller: any, feature: any)
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(
				controller.maid:Add(AccessKickPolicy.whenFeatureDisallowed(controller.serviceBag, POLICY_NAME, feature))
			)
		)
		controller.accessPolicyService:SetPolicyEnabled(POLICY_NAME, true)
	end

	local function feature(controller: any, factName: string)
		local built = controller.maid:Add(AccessFeature.anyOf("chapters", { factName }))
		controller.maid:GiveTask(controller.accessDataService:RegisterFeature(built))
		return built
	end

	it("does not kick while the verdict is unresolved", function()
		-- The trap this binding exists to close: an unresolved state IS a disallowed state, so a
		-- hand-written `not isAllowed(state)` would kick everyone whose lookup had not landed.
		local controller = setup()
		local built = feature(controller, AccessFactNames.PLAYER_IS_ADMIN)
		armed(controller, built)

		local player = controller.fakePlayer()
		controller.setAdmin(player, nil)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:destroy()
	end)

	it("does not kick an allowed player", function()
		local controller = setup()
		local built = feature(controller, AccessFactNames.PLAYER_IS_ADMIN)
		armed(controller, built)

		local player = controller.fakePlayer()
		controller.setAdmin(player, true)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).toEqual(nil)

		controller:destroy()
	end)

	it("kicks a player the feature refuses for a real reason", function()
		local controller = setup()
		local built = feature(controller, AccessFactNames.PLAYER_IS_ADMIN)
		armed(controller, built)

		local player = controller.fakePlayer()
		controller.setAdmin(player, false)
		controller.accessPolicyService:AddPlayer(player)

		expect(PlayerMock.getKickMessage(player)).never.toEqual(nil)

		controller:destroy()
	end)

	it("declares the feature it was bound to", function()
		local controller = setup()
		local built = feature(controller, AccessFactNames.PLAYER_IS_ADMIN)
		armed(controller, built)

		local policy = controller.accessPolicyService:GetPolicy(POLICY_NAME)
		expect(#(policy :: any):GetFeatures()).toEqual(1)

		controller:destroy()
	end)
end)

describe("AccessPolicyService query API", function()
	it("tracks a policy being switched on and off, live", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)

		local last = nil
		controller.maid:GiveTask(controller.accessPolicyService:ObserveIsPolicyEnabled("noop"):Subscribe(function(value)
			last = value
		end))

		expect(last).toEqual(false)

		controller.accessPolicyService:SetPolicyEnabled("noop", true)
		expect(last).toEqual(true)

		controller.accessPolicyService:SetPolicyEnabled("noop", false)
		expect(last).toEqual(false)

		controller:destroy()
	end)

	it("reports false for a policy nobody registered rather than erroring", function()
		local controller = setup()

		local last = nil
		controller.maid:GiveTask(
			controller.accessPolicyService:ObserveIsPolicyEnabled("nosuch"):Subscribe(function(value)
				last = value
			end)
		)

		expect(last).toEqual(false)

		controller:destroy()
	end)

	it("observes the registry as policies are added", function()
		local controller = setup()

		local last = nil
		controller.maid:GiveTask(controller.accessPolicyService:ObservePolicyNames():Subscribe(function(value)
			last = value
		end))

		local before = #(last :: any)
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)

		expect(#(last :: any)).toEqual(before + 1)

		controller:destroy()
	end)

	it("answers which policies read a fact", function()
		-- The question a bug report actually poses: this fact just flipped, so what acts on it?
		local controller = setup()

		expect(controller.accessPolicyService:GetPolicyNamesReadingFact(AccessFactNames.PLAYER_IS_ADMIN)).toEqual({
			AccessPolicyNames.KICK_ON_NON_ADMIN,
		})
		expect(controller.accessPolicyService:GetPolicyNamesReadingFact("somethingElse")).toEqual({})

		controller:destroy()
	end)

	it("answers which policies read a feature", function()
		local controller = setup()
		local feature = controller.maid:Add(AccessFeature.anyOf("shop", {}))

		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(controller.maid:Add(AccessPolicy.new(controller.serviceBag, {
				policyName = "watchShop",
				features = { feature },
				apply = function()
					return nil
				end,
			})))
		)

		expect(controller.accessPolicyService:GetPolicyNamesReadingFeature(feature)).toEqual({ "watchShop" })

		controller:destroy()
	end)
end)

describe("AccessPolicyService.IsPolicyActiveForPlayer", function()
	it("is false while the policy is enabled but the player is not tracked", function()
		-- Three things have to be true, and IsPolicyEnabled alone misleads about two of them.
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		local player = controller.fakePlayer()

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(true)
		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "noop")).toEqual(false)

		controller.accessPolicyService:AddPlayer(player)
		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "noop")).toEqual(true)

		controller:destroy()
	end)

	it("is false for a policy that belongs to the other realm", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(controller.maid:Add(AccessPolicy.new(controller.serviceBag, {
				policyName = "clientOnly",
				realm = AccessPolicyRealm.CLIENT,
				apply = function()
					return nil
				end,
			})))
		)
		controller.accessPolicyService:SetPolicyEnabled("clientOnly", true)

		local player = controller.fakePlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "clientOnly")).toEqual(false)

		controller:destroy()
	end)

	it("is false for a policy nobody registered", function()
		local controller = setup()
		local player = controller.fakePlayer()
		controller.accessPolicyService:AddPlayer(player)

		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "nosuch")).toEqual(false)

		controller:destroy()
	end)
end)

describe("AccessPolicyService per-player policy queries", function()
	it("is false while the policy is on but this player is not tracked", function()
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		local player = controller.fakePlayer()
		local last = nil
		controller.maid:GiveTask(
			controller.accessPolicyService:ObserveIsPolicyActiveForPlayer(player, "noop"):Subscribe(function(value)
				last = value
			end)
		)

		expect(last).toEqual(false)

		controller.accessPolicyService:AddPlayer(player)
		expect(controller.accessPolicyService:IsPolicyActiveForPlayer(player, "noop")).toEqual(true)

		controller:destroy()
	end)

	it("settles only once the policy is actually running for the player", function()
		-- "Not yet" is not an outcome worth settling a promise on.
		local controller = setup()
		controller.maid:GiveTask(
			controller.accessPolicyService:RegisterPolicy(countingPolicy(controller, "noop", { n = 0 }))
		)

		local player = controller.fakePlayer()
		controller.accessPolicyService:AddPlayer(player)

		local promise =
			controller.maid:GivePromise(controller.accessPolicyService:PromiseIsPolicyActiveForPlayer(player, "noop"))
		expect(promise:IsPending()).toEqual(true)

		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)

		controller:destroy()
	end)
end)

describe("AccessPolicy self-query through the tie", function()
	it("answers without holding a service, and says no for a player nobody is tracking", function()
		-- The value cannot be asserted for a tracked player here: the tie is implemented on
		-- ReplicatedStorage and the test place has several live bags, so Find may resolve another one.
		-- An untracked player is false in every bag, which is the part that is actually deterministic.
		local controller = setup()
		local policy = countingPolicy(controller, "noop", { n = 0 })
		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(policy))
		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		local untracked = controller.fakePlayer()

		expect(policy:IsPolicyActiveForPlayer(untracked)).toEqual(false)

		controller:destroy()
	end)

	it("says no for a policy no service has ever heard of", function()
		-- Never registered anywhere, so no service can report it active. Asserted against an untracked
		-- player because the tie lives on ReplicatedStorage and this place has several live bags.
		local controller = setup()
		local policy = countingPolicy(controller, "orphan", { n = 0 })

		expect(policy:IsPolicyActiveForPlayer(controller.fakePlayer())).toEqual(false)

		controller:destroy()
	end)
end)
