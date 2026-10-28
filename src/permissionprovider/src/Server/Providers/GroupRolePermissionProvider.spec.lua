--!strict
--[[
	@class GroupRolePermissionProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local GroupRolePermissionProvider = require("GroupRolePermissionProvider")
local GroupTestUtils = require("GroupTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local GROUP_ID = 12345
local ADMIN_ROLE_ID = 1001
local CREATOR_ROLE_ID = 1002
local OTHER_ROLE_ID = 1003

local remoteNameCounter = 0

local function setup()
	local maid = Maid.new()

	remoteNameCounter += 1
	local provider = maid:Add(GroupRolePermissionProvider.new(PermissionProviderUtils.createGroupRoleConfig({
		groupId = GROUP_ID,
		adminRoleIds = { ADMIN_ROLE_ID },
		creatorRoleIds = { CREATOR_ROLE_ID },
		remoteFunctionName = string.format("GroupRolePermissionProviderSpecRemote%d", remoteNameCounter),
	})))

	local controller = {
		provider = provider,
		fakePlayer = function(userId: number): Player
			local player = maid:Add(PlayerMock.new({ UserId = userId }))
			player.Parent = Workspace
			return player
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("GroupRolePermissionProvider.new", function()
	it("should reject a group rank config", function()
		expect(function()
			GroupRolePermissionProvider.new(PermissionProviderUtils.createGroupRankConfig({
				groupId = GROUP_ID,
				minAdminRequiredRank = 250,
				minCreatorRequiredRank = 254,
			}) :: any)
		end).toThrow("Bad configType")
	end)
end)

describe("GroupRolePermissionProvider.PromiseIsPermissionLevel", function()
	it("should deny both levels to a non-member", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsAdmin(player))).toEqual(false)
		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:Destroy()
	end)

	it("should grant admin but deny creator for an admin role", function()
		local controller = setup()
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 1, role = "Developer", roleId = ADMIN_ROLE_ID })

		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsAdmin(player))).toEqual(true)
		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:Destroy()
	end)

	it("should grant both levels for a creator role", function()
		local controller = setup()
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 1, role = "Owner", roleId = CREATOR_ROLE_ID })

		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsAdmin(player))).toEqual(true)
		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsCreator(player))).toEqual(true)

		controller:Destroy()
	end)

	it("should ignore rank for a role that is not listed", function()
		local controller = setup()
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 255, role = "VIP", roleId = OTHER_ROLE_ID })

		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsAdmin(player))).toEqual(false)
		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:Destroy()
	end)

	it("should grant admin when any of several held roles is listed", function()
		local controller = setup()
		local player = controller.fakePlayer(111)
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", {
			IsMember = true,
			Roles = {
				{ Id = OTHER_ROLE_ID, Name = "VIP", Rank = 50 },
				{ Id = ADMIN_ROLE_ID, Name = "Developer", Rank = 1 },
			},
		}, GROUP_ID)

		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsAdmin(player))).toEqual(true)

		controller:Destroy()
	end)

	it("should ignore a role held in a different group", function()
		local controller = setup()
		local player = controller.fakePlayer(111)
		GroupTestUtils.assignGroupInfo(player, 99999, { rank = 1, role = "Owner", roleId = CREATOR_ROLE_ID })

		expect(PromiseTestUtils.awaitFulfilled(controller.provider:PromiseIsAdmin(player))).toEqual(false)

		controller:Destroy()
	end)

	it("should reject a player outside the game hierarchy", function()
		local controller = setup()
		local maid = Maid.new()
		local unparented = maid:Add(PlayerMock.new({ UserId = 111 }))

		expect(function()
			controller.provider:PromiseIsPermissionLevel(unparented, PermissionLevel.CREATOR)
		end).toThrow("Bad player")

		maid:DoCleaning()
		controller:Destroy()
	end)

	it("should reject an invalid permission level", function()
		local controller = setup()
		local player = controller.fakePlayer(111)

		expect(function()
			controller.provider:PromiseIsPermissionLevel(player, "not-a-level" :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("GroupRolePermissionProvider.Start", function()
	it("should start and clean up without error", function()
		local controller = setup()

		expect(function()
			controller.provider:Start()
		end).never.toThrow()

		controller:Destroy()
	end)
end)
