--!strict
--[[
	@class PlayerThumbnailUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerThumbnailUtils = require("PlayerThumbnailUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerThumbnailUtils.promiseUserThumbnail against a mock", function()
	it("resolves the derived rbxthumb URL with defaulted type and size", function()
		local player = PlayerMock.new({ UserId = 90081001 })
		player.Parent = Workspace

		local outcome, content = PromiseTestUtils.awaitOutcome(PlayerThumbnailUtils.promiseUserThumbnail(90081001))

		expect(outcome).toBe("resolved")
		expect(content).toBe("rbxthumb://type=AvatarHeadShot&id=90081001&w=100&h=100")

		player:Destroy()
	end)

	it("derives the URL from the requested type and size", function()
		local player = PlayerMock.new({ UserId = 90081002 })
		player.Parent = Workspace

		local outcome, content = PromiseTestUtils.awaitOutcome(
			PlayerThumbnailUtils.promiseUserThumbnail(
				90081002,
				Enum.ThumbnailType.AvatarThumbnail,
				Enum.ThumbnailSize.Size420x420
			)
		)

		expect(outcome).toBe("resolved")
		expect(content).toBe("rbxthumb://type=Avatar&id=90081002&w=420&h=420")

		player:Destroy()
	end)
end)

describe("PlayerThumbnailUtils.promiseUserName against a mock", function()
	it("resolves the default Name-derived username", function()
		local player = PlayerMock.new({ UserId = 90081003 })
		player.Parent = Workspace

		local outcome, name = PromiseTestUtils.awaitOutcome(PlayerThumbnailUtils.promiseUserName(90081003))

		expect(outcome).toBe("resolved")
		expect(name).toBe(player.Name)

		player:Destroy()
	end)

	it("resolves an injected username from the shared user-info domain", function()
		local player = PlayerMock.new({ UserId = 90081004 })
		player.Parent = Workspace
		PlayerMock.writeLookup(player, "UserService.GetUserInfosByUserIdsAsync", 0, {
			Id = 90081004,
			Username = "shared_domain_name",
			DisplayName = "Shared",
			HasVerifiedBadge = false,
		})

		local outcome, name = PromiseTestUtils.awaitOutcome(PlayerThumbnailUtils.promiseUserName(90081004))

		expect(outcome).toBe("resolved")
		expect(name).toBe("shared_domain_name")

		player:Destroy()
	end)
end)
