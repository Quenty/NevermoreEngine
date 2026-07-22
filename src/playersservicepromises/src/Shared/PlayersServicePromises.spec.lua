--!strict
--[[
	@class PlayersServicePromises.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayersServicePromises = require("PlayersServicePromises")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayersServicePromises.promiseUserIdFromName against a mock", function()
	it("resolves the mock's UserId by its default Name-derived username", function()
		local player = PlayerMock.new({ UserId = 90071001 })
		player.Parent = Workspace

		local outcome, userId = PromiseTestUtils.awaitOutcome(PlayersServicePromises.promiseUserIdFromName(player.Name))

		expect(outcome).toBe("resolved")
		expect(userId).toBe(90071001)

		player:Destroy()
	end)

	it("resolves the mock's UserId by an injected username", function()
		local player = PlayerMock.new({ UserId = 90071002 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, {
			Id = 90071002,
			Username = "injected_lookup_name",
			DisplayName = "Injected",
			HasVerifiedBadge = false,
		})

		local outcome, userId =
			PromiseTestUtils.awaitOutcome(PlayersServicePromises.promiseUserIdFromName("injected_lookup_name"))

		expect(outcome).toBe("resolved")
		expect(userId).toBe(90071002)

		player:Destroy()
	end)

	it("asserts on a non-string name", function()
		expect(function()
			PlayersServicePromises.promiseUserIdFromName(12345 :: any)
		end).toThrow()
	end)
end)
