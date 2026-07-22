--!strict
--[[
	Coverage for GroupPermissionProvider using PlayerMock players. Group membership is injected
	via GroupTestUtils.assignGroupInfo (defaulting to non-member, rank 0 — a mock is in no real
	group), intercepted at the GroupService engine calls, so permission outcomes flow through
	GroupUtils' real parsing and the provider's real threshold logic deterministically — no group
	API call and no Studio dependence.

	@class GroupPermissionProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local GroupPermissionProvider = require("GroupPermissionProvider")
local GroupTestUtils = require("GroupTestUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local remoteNameCounter = 0

local function setup(options: { minAdminRequiredRank: number, minCreatorRequiredRank: number })
	local maid = Maid.new()

	-- Unique remote function name so providers from separate tests never share the global remote.
	remoteNameCounter += 1
	local provider = maid:Add(GroupPermissionProvider.new(PermissionProviderUtils.createGroupRankConfig({
		groupId = 12345,
		minAdminRequiredRank = options.minAdminRequiredRank,
		minCreatorRequiredRank = options.minCreatorRequiredRank,
		remoteFunctionName = string.format("GroupPermissionProviderSpecRemote%d", remoteNameCounter),
	})))

	return {
		provider = provider,
		fakePlayer = function(userId: number): Player
			local player = maid:Add(PlayerMock.new({ UserId = userId }))
			player.Parent = Workspace
			return player
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

describe("GroupPermissionProvider.new", function()
	it("should reject a single user config", function()
		expect(function()
			GroupPermissionProvider.new(PermissionProviderUtils.createSingleUserConfig({
				userId = 12345,
			}) :: any)
		end).toThrow("Bad configType")
	end)
end)

describe("GroupPermissionProvider.PromiseIsPermissionLevel", function()
	it("should grant both levels when the rank thresholds are met", function()
		local controller = setup({ minAdminRequiredRank = 0, minCreatorRequiredRank = 0 })
		local player = controller.fakePlayer(111)

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(true)
		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(true)

		controller:destroy()
	end)

	it("should deny both levels when the rank thresholds are not met", function()
		local controller = setup({ minAdminRequiredRank = 100, minCreatorRequiredRank = 200 })
		local player = controller.fakePlayer(111)

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(false)
		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:destroy()
	end)

	it("should grant admin but deny creator for a tiered config", function()
		local controller = setup({ minAdminRequiredRank = 0, minCreatorRequiredRank = 1 })
		local player = controller.fakePlayer(111)

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(true)
		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:destroy()
	end)

	it("should grant admin but deny creator from an injected group rank", function()
		local controller = setup({ minAdminRequiredRank = 100, minCreatorRequiredRank = 200 })
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, 12345, { rank = 150, role = "Admin" })

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(true)
		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:destroy()
	end)

	it("should grant both levels from an injected group rank meeting both thresholds", function()
		local controller = setup({ minAdminRequiredRank = 100, minCreatorRequiredRank = 200 })
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, 12345, { rank = 255, role = "Owner" })

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(true)
		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(true)

		controller:destroy()
	end)

	it("should ignore a rank injected for a different group", function()
		local controller = setup({ minAdminRequiredRank = 100, minCreatorRequiredRank = 200 })
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, 99999, { rank = 255, role = "Owner" })

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(false)

		controller:destroy()
	end)

	it("should reject a player outside the game hierarchy", function()
		local controller = setup({ minAdminRequiredRank = 0, minCreatorRequiredRank = 0 })
		local maid = Maid.new()
		local unparented = maid:Add(PlayerMock.new({ UserId = 111 }))

		expect(function()
			controller.provider:PromiseIsPermissionLevel(unparented, PermissionLevel.CREATOR)
		end).toThrow("Bad player")

		maid:DoCleaning()
		controller:destroy()
	end)

	it("should reject a non-player value", function()
		local controller = setup({ minAdminRequiredRank = 0, minCreatorRequiredRank = 0 })

		expect(function()
			controller.provider:PromiseIsPermissionLevel(nil :: any, PermissionLevel.ADMIN)
		end).toThrow("Bad player")

		controller:destroy()
	end)

	it("should reject an invalid permission level", function()
		local controller = setup({ minAdminRequiredRank = 0, minCreatorRequiredRank = 0 })
		local player = controller.fakePlayer(111)

		expect(function()
			controller.provider:PromiseIsPermissionLevel(player, "not-a-level" :: any)
		end).toThrow()

		controller:destroy()
	end)
end)

describe("GroupPermissionProvider.Start", function()
	it("should start and clean up without error", function()
		local controller = setup({ minAdminRequiredRank = 100, minCreatorRequiredRank = 200 })

		expect(function()
			controller.provider:Start()
		end).never.toThrow()

		controller:destroy()
	end)
end)
