--!strict
--[[
	@class UserServiceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local UserServiceUtils = require("UserServiceUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("UserServiceUtils.promiseUserInfosByUserIds against mocks", function()
	it("resolves the identity-derived info for a mock with no injection", function()
		local player = PlayerMock.new({ UserId = 90061001, DisplayName = "Derived Display" })
		player.Parent = Workspace

		local outcome, userInfos =
			PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseUserInfosByUserIds({ 90061001 }))

		expect(outcome).toBe("resolved")
		expect(#userInfos).toBe(1)
		expect(userInfos[1].Id).toBe(90061001)
		expect(userInfos[1].Username).toBe(player.Name)
		expect(userInfos[1].DisplayName).toBe("Derived Display")
		expect(userInfos[1].HasVerifiedBadge).toBe(false)

		player:Destroy()
	end)

	it("resolves an injected user info over the derived default", function()
		local player = PlayerMock.new({ UserId = 90061002 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, {
			Id = 90061002,
			Username = "injected_username",
			DisplayName = "Injected Display",
			HasVerifiedBadge = true,
		})

		local outcome, userInfos =
			PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseUserInfosByUserIds({ 90061002 }))

		expect(outcome).toBe("resolved")
		expect(userInfos[1].Username).toBe("injected_username")
		expect(userInfos[1].HasVerifiedBadge).toBe(true)

		player:Destroy()
	end)

	it("resolves multiple mocks in one batch", function()
		local playerOne = PlayerMock.new({ UserId = 90061003 })
		playerOne.Parent = Workspace
		local playerTwo = PlayerMock.new({ UserId = 90061004 })
		playerTwo.Parent = Workspace

		local outcome, userInfos =
			PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseUserInfosByUserIds({ 90061003, 90061004 }))

		expect(outcome).toBe("resolved")
		expect(#userInfos).toBe(2)
		expect(userInfos[1].Id).toBe(90061003)
		expect(userInfos[2].Id).toBe(90061004)

		playerOne:Destroy()
		playerTwo:Destroy()
	end)

	it("resolves an empty list for no userIds without touching the engine", function()
		local outcome, userInfos = PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseUserInfosByUserIds({}))

		expect(outcome).toBe("resolved")
		expect(userInfos).toEqual({})
	end)
end)

describe("UserServiceUtils wrappers against a mock", function()
	it("promiseUserInfo resolves the single info", function()
		local player = PlayerMock.new({ UserId = 90061005 })
		player.Parent = Workspace

		local outcome, userInfo = PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseUserInfo(90061005))

		expect(outcome).toBe("resolved")
		expect(userInfo.Id).toBe(90061005)

		player:Destroy()
	end)

	it("promiseDisplayName and promiseUserName agree with the injected info", function()
		local player = PlayerMock.new({ UserId = 90061006 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, {
			Id = 90061006,
			Username = "the_username",
			DisplayName = "The Display",
			HasVerifiedBadge = false,
		})

		local displayOutcome, displayName = PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseDisplayName(90061006))
		local nameOutcome, userName = PromiseTestUtils.awaitOutcome(UserServiceUtils.promiseUserName(90061006))

		expect(displayOutcome).toBe("resolved")
		expect(displayName).toBe("The Display")
		expect(nameOutcome).toBe("resolved")
		expect(userName).toBe("the_username")

		player:Destroy()
	end)
end)
