--!strict
--[[
	@class FriendUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local FriendUtils = require("FriendUtils")
local Jest = require("Jest")
local PagesDatabase = require("PagesDatabase")
local PagesProxy = require("PagesProxy")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function makeFriendData(userId: number, isOnline: boolean)
	return {
		Id = userId,
		Username = string.format("friend_%d", userId),
		DisplayName = string.format("Friend %d", userId),
		IsOnline = isOnline,
	}
end

describe("FriendUtils.promiseAllFriends against a mock", function()
	it("resolves the injected friends list", function()
		local player = PlayerMock.new({ UserId = 90041001 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "Players.GetFriendsAsync", 0, {
			makeFriendData(90041002, true),
			makeFriendData(90041003, false),
		})

		local outcome, friends = PromiseTestUtils.awaitOutcome(FriendUtils.promiseAllFriends(90041001))

		expect(outcome).toBe("resolved")
		expect(#friends).toBe(2)
		expect(friends[1].Id).toBe(90041002)
		expect(friends[1].Username).toBe("friend_90041002")
		expect(friends[2].IsOnline).toBe(false)

		player:Destroy()
	end)

	it("resolves an empty list for a mock with no injected friends", function()
		local player = PlayerMock.new({ UserId = 90041004 })
		player.Parent = Workspace

		local outcome, friends = PromiseTestUtils.awaitOutcome(FriendUtils.promiseAllFriends(90041004))

		expect(outcome).toBe("resolved")
		expect(friends).toEqual({})

		player:Destroy()
	end)

	it("stops at limitMaxFriends", function()
		local player = PlayerMock.new({ UserId = 90041005 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "Players.GetFriendsAsync", 0, {
			makeFriendData(90041006, true),
			makeFriendData(90041007, true),
			makeFriendData(90041008, true),
		})

		local outcome, friends = PromiseTestUtils.awaitOutcome(FriendUtils.promiseAllFriends(90041005, 2))

		expect(outcome).toBe("resolved")
		expect(#friends).toBe(2)

		player:Destroy()
	end)
end)

describe("FriendUtils.iterateFriendsYielding", function()
	it("iterates across page boundaries", function()
		local pages = PagesProxy.new(PagesDatabase.fromPageData({
			{ makeFriendData(90041009, true) },
			{ makeFriendData(90041010, false) },
		}))

		local seen = {}
		for userData in FriendUtils.iterateFriendsYielding(pages :: any) do
			table.insert(seen, userData.Id)
		end

		expect(seen).toEqual({ 90041009, 90041010 })
	end)
end)

describe("FriendUtils.onlineFriends", function()
	it("filters to online friends only", function()
		local friends = {
			makeFriendData(90041011, true),
			makeFriendData(90041012, false),
		}

		local online = FriendUtils.onlineFriends(friends)

		expect(#online).toBe(1)
		expect(online[1].Id).toBe(90041011)
	end)
end)

describe("FriendUtils.friendsNotInGame", function()
	it("filters out friends whose player is in the game", function()
		-- Mocks are not in Players:GetPlayers(), so all injected friends count as not in game
		local friends = {
			makeFriendData(90041013, true),
		}

		local notInGame = FriendUtils.friendsNotInGame(friends)

		expect(#notInGame).toBe(1)
	end)
end)
