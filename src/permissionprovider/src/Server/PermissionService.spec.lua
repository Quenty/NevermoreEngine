--!strict
--[[
	Coverage for PermissionService's ServiceBag-driven lifecycle and permission queries, with a
	single-user (creator) provider config and PlayerMock players.

	The deny cases assume RunService:IsStudio() == false (true in the cloud test runner); in Studio
	the service short-circuits every permission query to true.

	@class PermissionService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PermissionService = require("PermissionService")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local CREATOR_USER_ID = 12345

local remoteNameCounter = 0

local function setup()
	local maid = Maid.new()
	local serviceBag = maid:Add(ServiceBag.new())
	local permissionService: PermissionService.PermissionService = serviceBag:GetService(PermissionService) :: any
	serviceBag:Init()

	-- Unique remote function name so services from separate tests never share the global remote.
	remoteNameCounter += 1
	local remoteFunctionName = string.format("PermissionServiceSpecRemote%d", remoteNameCounter)

	return {
		serviceBag = serviceBag,
		permissionService = permissionService,
		singleUserConfig = function(userId: number)
			return PermissionProviderUtils.createSingleUserConfig({
				userId = userId,
				remoteFunctionName = remoteFunctionName,
			})
		end,
		fakePlayer = function(userId: number): Player
			return maid:Add(PlayerMock.new({ UserId = userId }))
		end,
		awaitBool = function(promise: any): boolean
			expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			return value
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("PermissionService initialization", function()
	it("should initialize and start with a configured provider", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))

		expect(function()
			controller.serviceBag:Start()
		end).never.toThrow()

		controller:destroy()
	end)

	it("should start with a provider derived from the game when none is configured", function()
		local controller = setup()

		expect(function()
			controller.serviceBag:Start()
		end).never.toThrow()

		controller:destroy()
	end)

	it("should resolve the permission provider after start", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))

		local promise = controller.permissionService:PromisePermissionProvider()
		expect(promise:IsPending()).toEqual(true)

		controller.serviceBag:Start()

		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local ok, provider = promise:Yield()
		expect(ok).toEqual(true)
		expect((provider :: any).ClassName).toEqual("CreatorPermissionProvider")

		controller:destroy()
	end)
end)

describe("PermissionService.SetProviderFromConfig", function()
	it("should reject a second provider config", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))

		expect(function()
			controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		end).toThrow("Already have provider set")

		controller:destroy()
	end)

	it("should reject an unknown config type", function()
		local controller = setup()

		expect(function()
			controller.permissionService:SetProviderFromConfig({ type = "UnknownConfigType" } :: any)
		end).toThrow("Bad provider")

		controller:destroy()
	end)
end)

describe("PermissionService permission queries", function()
	it("should treat the configured user as an admin", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		controller.serviceBag:Start()

		local player = controller.fakePlayer(CREATOR_USER_ID)
		expect(controller.awaitBool(controller.permissionService:PromiseIsAdmin(player))).toEqual(true)

		controller:destroy()
	end)

	it("should treat the configured user as a creator", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		controller.serviceBag:Start()

		local player = controller.fakePlayer(CREATOR_USER_ID)
		expect(controller.awaitBool(controller.permissionService:PromiseIsCreator(player))).toEqual(true)

		controller:destroy()
	end)

	it("should deny another user admin permission", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		controller.serviceBag:Start()

		local player = controller.fakePlayer(CREATOR_USER_ID + 1)
		expect(controller.awaitBool(controller.permissionService:PromiseIsAdmin(player))).toEqual(false)

		controller:destroy()
	end)

	it("should reject a non-player value", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		controller.serviceBag:Start()

		expect(function()
			controller.permissionService:PromiseIsAdmin(nil :: any)
		end).toThrow("bad player")

		controller:destroy()
	end)

	it("should reject an invalid permission level", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		controller.serviceBag:Start()

		local player = controller.fakePlayer(CREATOR_USER_ID)
		expect(function()
			controller.permissionService:PromiseIsPermissionLevel(player, "not-a-level" :: any)
		end).toThrow("Bad permissionLevel")

		controller:destroy()
	end)
end)

describe("PermissionService.ObservePermissionedPlayersBrio", function()
	it("should subscribe and unsubscribe without error on an empty server", function()
		local controller = setup()
		controller.permissionService:SetProviderFromConfig(controller.singleUserConfig(CREATOR_USER_ID))
		controller.serviceBag:Start()

		expect(function()
			local subscription = controller.permissionService
				:ObservePermissionedPlayersBrio(PermissionLevel.ADMIN)
				:Subscribe(function() end)
			subscription:Destroy()
		end).never.toThrow()

		controller:destroy()
	end)
end)
