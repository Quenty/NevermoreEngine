--!strict
--[[
	@class PermissionProviderUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderUtils = require("PermissionProviderUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PermissionProviderUtils.createGroupRankConfig", function()
	it("should create a group rank config with the given ranks", function()
		local config = PermissionProviderUtils.createGroupRankConfig({
			groupId = 12345,
			minAdminRequiredRank = 250,
			minCreatorRequiredRank = 254,
		})

		expect(config.type).toEqual(PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE)
		expect(config.groupId).toEqual(12345)
		expect(config.minAdminRequiredRank).toEqual(250)
		expect(config.minCreatorRequiredRank).toEqual(254)
	end)

	it("should default the remote function name", function()
		local config = PermissionProviderUtils.createGroupRankConfig({
			groupId = 12345,
			minAdminRequiredRank = 250,
			minCreatorRequiredRank = 254,
		})

		expect(config.remoteFunctionName).toEqual(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME)
	end)

	it("should honor a custom remote function name", function()
		local config = PermissionProviderUtils.createGroupRankConfig({
			groupId = 12345,
			minAdminRequiredRank = 250,
			minCreatorRequiredRank = 254,
			remoteFunctionName = "CustomRemoteFunction",
		})

		expect(config.remoteFunctionName).toEqual("CustomRemoteFunction")
	end)

	it("should reject a missing groupId", function()
		expect(function()
			PermissionProviderUtils.createGroupRankConfig({
				minAdminRequiredRank = 250,
				minCreatorRequiredRank = 254,
			} :: any)
		end).toThrow("Bad groupId")
	end)

	it("should reject a missing minCreatorRequiredRank", function()
		expect(function()
			PermissionProviderUtils.createGroupRankConfig({
				groupId = 12345,
				minAdminRequiredRank = 250,
			} :: any)
		end).toThrow("Bad minCreatorRequiredRank")
	end)

	it("should reject a missing minAdminRequiredRank", function()
		expect(function()
			PermissionProviderUtils.createGroupRankConfig({
				groupId = 12345,
				minCreatorRequiredRank = 254,
			} :: any)
		end).toThrow("Bad minAdminRequiredRank")
	end)
end)

describe("PermissionProviderUtils.createGroupRoleConfig", function()
	it("should create a group role config with the given roles", function()
		local config = PermissionProviderUtils.createGroupRoleConfig({
			groupId = 12345,
			adminRoleIds = { 1001, 1002 },
			creatorRoleIds = { 1003 },
		})

		expect(config.type).toEqual(PermissionProviderConstants.GROUP_ROLE_CONFIG_TYPE)
		expect(config.groupId).toEqual(12345)
		expect(config.adminRoleIds).toEqual({ 1001, 1002 })
		expect(config.creatorRoleIds).toEqual({ 1003 })
		expect(config.remoteFunctionName).toEqual(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME)
	end)

	it("should copy the role lists", function()
		local adminRoleIds = { 1001 }
		local config = PermissionProviderUtils.createGroupRoleConfig({
			groupId = 12345,
			adminRoleIds = adminRoleIds,
			creatorRoleIds = {},
		})
		table.insert(adminRoleIds, 1002)

		expect(config.adminRoleIds).toEqual({ 1001 })
	end)

	it("should reject a missing groupId", function()
		expect(function()
			PermissionProviderUtils.createGroupRoleConfig({
				adminRoleIds = {},
				creatorRoleIds = {},
			} :: any)
		end).toThrow("Bad groupId")
	end)

	it("should reject a missing role list", function()
		expect(function()
			PermissionProviderUtils.createGroupRoleConfig({
				groupId = 12345,
				creatorRoleIds = {},
			} :: any)
		end).toThrow("Bad adminRoleIds")
	end)

	it("should reject a role id that is not a number", function()
		expect(function()
			PermissionProviderUtils.createGroupRoleConfig({
				groupId = 12345,
				adminRoleIds = {},
				creatorRoleIds = { "Owner" },
			} :: any)
		end).toThrow("Bad creatorRoleIds")
	end)
end)

describe("PermissionProviderUtils.createSingleUserConfig", function()
	it("should create a single user config", function()
		local config = PermissionProviderUtils.createSingleUserConfig({
			userId = 12345,
		})

		expect(config.type).toEqual(PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE)
		expect(config.userId).toEqual(12345)
		expect(config.remoteFunctionName).toEqual(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME)
	end)

	it("should honor a custom remote function name", function()
		local config = PermissionProviderUtils.createSingleUserConfig({
			userId = 12345,
			remoteFunctionName = "CustomRemoteFunction",
		})

		expect(config.remoteFunctionName).toEqual("CustomRemoteFunction")
	end)

	it("should reject a missing userId", function()
		expect(function()
			PermissionProviderUtils.createSingleUserConfig({} :: any)
		end).toThrow("Bad userId")
	end)
end)

describe("PermissionProviderUtils.createConfigFromGame", function()
	it("should create a config matching the game's creator type", function()
		local config = PermissionProviderUtils.createConfigFromGame()

		if game.CreatorType == Enum.CreatorType.Group then
			expect(config.type).toEqual(PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE)
			expect((config :: any).groupId).toEqual(game.CreatorId)
		else
			expect(config.type).toEqual(PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE)
			expect((config :: any).userId).toEqual(game.CreatorId)
		end
	end)
end)
