--!strict
--[[
	Coverage for CreatorPermissionProvider: a single configured userId is both admin and creator,
	everyone else is neither. Players are stood in by PlayerMock, whose seeded UserId the provider
	reads through PlayerMock.read.

	The negative cases assume RunService:IsStudio() == false (true in the cloud test runner); in
	Studio the provider grants everyone permission.

	@class CreatorPermissionProvider.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local CreatorPermissionProvider = require("CreatorPermissionProvider")
local Jest = require("Jest")
local Maid = require("Maid")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local CREATOR_USER_ID = 12345

local function setup()
	local maid = Maid.new()
	local provider = maid:Add(CreatorPermissionProvider.new(PermissionProviderUtils.createSingleUserConfig({
		userId = CREATOR_USER_ID,
	})))

	return {
		provider = provider,
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

describe("CreatorPermissionProvider.new", function()
	it("should reject a group rank config", function()
		expect(function()
			CreatorPermissionProvider.new(PermissionProviderUtils.createGroupRankConfig({
				groupId = 12345,
				minAdminRequiredRank = 250,
				minCreatorRequiredRank = 254,
			}) :: any)
		end).toThrow("Bad configType")
	end)
end)

describe("CreatorPermissionProvider.PromiseIsPermissionLevel", function()
	it("should treat the configured user as an admin", function()
		local controller = setup()
		local player = controller.fakePlayer(CREATOR_USER_ID)

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(true)

		controller:destroy()
	end)

	it("should treat the configured user as a creator", function()
		local controller = setup()
		local player = controller.fakePlayer(CREATOR_USER_ID)

		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(true)

		controller:destroy()
	end)

	it("should deny another user admin permission", function()
		local controller = setup()
		local player = controller.fakePlayer(CREATOR_USER_ID + 1)

		expect(controller.awaitBool(controller.provider:PromiseIsAdmin(player))).toEqual(false)

		controller:destroy()
	end)

	it("should deny another user creator permission", function()
		local controller = setup()
		local player = controller.fakePlayer(CREATOR_USER_ID + 1)

		expect(controller.awaitBool(controller.provider:PromiseIsCreator(player))).toEqual(false)

		controller:destroy()
	end)

	it("should resolve synchronously for the IsAdmin wrapper", function()
		local controller = setup()
		local player = controller.fakePlayer(CREATOR_USER_ID)

		expect(controller.provider:IsAdmin(player)).toEqual(true)

		controller:destroy()
	end)

	it("should reject a non-player value", function()
		local controller = setup()

		expect(function()
			controller.provider:PromiseIsPermissionLevel(nil :: any, PermissionLevel.ADMIN)
		end).toThrow("Bad player")

		controller:destroy()
	end)

	it("should reject an invalid permission level", function()
		local controller = setup()
		local player = controller.fakePlayer(CREATOR_USER_ID)

		expect(function()
			controller.provider:PromiseIsPermissionLevel(player, "not-a-level" :: any)
		end).toThrow()

		controller:destroy()
	end)
end)
