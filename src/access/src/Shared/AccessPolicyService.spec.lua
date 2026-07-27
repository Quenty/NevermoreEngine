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
local AccessPolicyService = require("AccessPolicyService")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
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

local function countingPolicy(policyName: string, applied: { n: number })
	return AccessPolicy.new(policyName, {
		apply = function()
			applied.n += 1

			return function()
				applied.n -= 1
			end
		end,
	})
end

describe("AccessPolicyService.RegisterPolicy", function()
	it("registers disabled, so shipping a policy does not switch it on", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", applied)))
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		expect(controller.accessPolicyService:IsPolicyEnabled("noop")).toEqual(false)
		expect(applied.n).toEqual(0)

		controller:destroy()
	end)

	it("lists a disabled policy anyway, so it can be discovered", function()
		local controller = setup()
		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", { n = 0 })))

		expect(controller.accessPolicyService:GetPolicyNames()).toEqual({ AccessPolicyNames.KICK_ON_NON_ADMIN, "noop" })

		controller:destroy()
	end)

	it("refuses two policies under one name", function()
		local controller = setup()
		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", { n = 0 })))

		expect(function()
			controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", { n = 0 }))
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

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", applied)))
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		controller.accessPolicyService:SetPolicyEnabled("noop", true)

		expect(applied.n).toEqual(2)

		controller:destroy()
	end)

	it("applies to a player who arrives while it is on", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", applied)))
		controller.accessPolicyService:SetPolicyEnabled("noop", true)
		controller.accessPolicyService:AddPlayer(controller.fakePlayer())

		expect(applied.n).toEqual(1)

		controller:destroy()
	end)

	it("tears down when switched off", function()
		local controller = setup()
		local applied = { n = 0 }

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", applied)))
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

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("noop", applied)))
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

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("a", a)))
		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(countingPolicy("b", b)))
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

		controller.maid:GiveTask(controller.accessPolicyService:RegisterPolicy(AccessPolicy.new("sneaky", {
			apply = function(context)
				return context.observeFact(AccessFactNames.PLAYER_IS_ADMIN):Subscribe(function() end)
			end,
		})))
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
				AccessKickPolicy.whenFactIs(POLICY_NAME, AccessFactNames.PLAYER_IS_ADMIN, false)
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
				AccessKickPolicy.whenFactIs(POLICY_NAME, AccessFactNames.PLAYER_IS_ADMIN, false)
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
				AccessKickPolicy.whenFactIs(POLICY_NAME, AccessFactNames.PLAYER_IS_ADMIN, false, {
					message = "staff only",
				})
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
			controller.accessDataService:RegisterFact(AccessFact.new(AccessFactNames.PLAYER_IS_ADMIN, {
				resolve = function()
					return true
				end,
				priority = AccessFactPriority.ELEVATED,
				source = "gameAllowlist",
			}))
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
			controller.accessPolicyService:RegisterPolicy(AccessKickPolicy.whenFeatureDisallowed(POLICY_NAME, feature))
		)
		controller.accessPolicyService:SetPolicyEnabled(POLICY_NAME, true)
	end

	local function feature(controller: any, factName: string)
		local built = AccessFeature.anyOf("chapters", { factName })
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
