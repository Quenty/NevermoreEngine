--!strict
--[[
	Coverage for GroupUtils rank/role resolution using PlayerMock players. Only the GroupService
	engine calls are intercepted (raw result shapes injected via PlayerMock.writeLookup /
	GroupTestUtils.assignGroupInfo), so the highest-role scan, GetGroupsAsync fallback ordering,
	and reject paths all execute for real.

	@class GroupUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local GroupTestUtils = require("GroupTestUtils")
local GroupUtils = require("GroupUtils")
local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local GROUP_ID = 372

describe("GroupUtils.promiseRankInGroup", function()
	it("should resolve 0 for a mock with no injected membership", function()
		local player = PlayerMock.new({ UserId = 111 })

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe(0)

		player:Destroy()
	end)

	it("should resolve an assigned rank", function()
		local player = PlayerMock.new({ UserId = 111 })
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 230, role = "Admin" })

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe(230)

		player:Destroy()
	end)

	it("should resolve the highest rank when the result carries multiple roles", function()
		local player = PlayerMock.new({ UserId = 111 })
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", GROUP_ID, {
			IsMember = true,
			Roles = {
				{ Name = "Member", Rank = 1 },
				{ Name = "Admin", Rank = 230 },
				{ Name = "Moderator", Rank = 150 },
			},
		})

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe(230)

		player:Destroy()
	end)

	it("should resolve from the GetGroupsAsync fallback when the primary result reports non-member", function()
		local player = PlayerMock.new({ UserId = 111 })
		PlayerMock.writeLookup(player, "GroupService.GetGroupsAsync", 0, {
			{ Id = GROUP_ID, Rank = 42, Role = "Member" },
		})

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe(42)

		player:Destroy()
	end)

	it("should ignore membership assigned for a different group", function()
		local player = PlayerMock.new({ UserId = 111 })
		GroupTestUtils.assignGroupInfo(player, 99999, { rank = 255, role = "Owner" })

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe(0)

		player:Destroy()
	end)

	it("should throw on a non-player value", function()
		expect(function()
			GroupUtils.promiseRankInGroup(nil :: any, GROUP_ID)
		end).toThrow("Bad player")
	end)

	it("should throw on a bad groupId", function()
		local player = PlayerMock.new({ UserId = 111 })

		expect(function()
			GroupUtils.promiseRankInGroup(player, "372" :: any)
		end).toThrow("Bad groupId")

		player:Destroy()
	end)
end)

describe("GroupUtils.promiseRoleInGroup", function()
	it("should resolve an assigned role", function()
		local player = PlayerMock.new({ UserId = 111 })
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 230, role = "Admin" })

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRoleInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe("Admin")

		player:Destroy()
	end)

	it("should resolve the highest role's name when the result carries multiple roles", function()
		local player = PlayerMock.new({ UserId = 111 })
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", GROUP_ID, {
			IsMember = true,
			Roles = {
				{ Name = "Member", Rank = 1 },
				{ Name = "Admin", Rank = 230 },
				{ Name = "Moderator", Rank = 150 },
			},
		})

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRoleInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe("Admin")

		player:Destroy()
	end)

	it("should resolve from the GetGroupsAsync fallback when the primary result reports non-member", function()
		local player = PlayerMock.new({ UserId = 111 })
		PlayerMock.writeLookup(player, "GroupService.GetGroupsAsync", 0, {
			{ Id = GROUP_ID, Rank = 42, Role = "Member" },
		})

		local outcome, value = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRoleInGroup(player, GROUP_ID))
		expect(outcome).toBe("resolved")
		expect(value).toBe("Member")

		player:Destroy()
	end)

	it("should reject for a mock with no injected membership, like a real non-member", function()
		local player = PlayerMock.new({ UserId = 111 })

		local outcome, err = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRoleInGroup(player, GROUP_ID))
		expect(outcome).toBe("rejected")
		expect(err).toBe("Role is not a string")

		player:Destroy()
	end)
end)

describe("GroupTestUtils.assignGroupInfo", function()
	it("should keep rank and role coherent from one assignment", function()
		local player = PlayerMock.new({ UserId = 111 })
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 150, role = "Moderator" })

		local _, rank = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		local _, role = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRoleInGroup(player, GROUP_ID))
		expect(rank).toBe(150)
		expect(role).toBe("Moderator")

		player:Destroy()
	end)

	it("should keep assignments to multiple groups independent", function()
		local player = PlayerMock.new({ UserId = 111 })
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 230, role = "Admin" })
		GroupTestUtils.assignGroupInfo(player, 99999, { rank = 5, role = "Member" })

		-- Clearing one group's primary result forces its answer through the shared GetGroupsAsync
		-- fallback list, proving the second assignment appended rather than replaced it.
		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", GROUP_ID, nil)

		local _, rank = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		local _, otherRank = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, 99999))
		expect(rank).toBe(230)
		expect(otherRank).toBe(5)

		player:Destroy()
	end)

	it("should replace an earlier assignment for the same group", function()
		local player = PlayerMock.new({ UserId = 111 })
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 10, role = "Member" })
		GroupTestUtils.assignGroupInfo(player, GROUP_ID, { rank = 20, role = "Moderator" })

		local _, rank = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(rank).toBe(20)

		PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", GROUP_ID, nil)
		local _, fallbackRank = PromiseTestUtils.awaitOutcome(GroupUtils.promiseRankInGroup(player, GROUP_ID))
		expect(fallbackRank).toBe(20)

		player:Destroy()
	end)

	it("should throw when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			GroupTestUtils.assignGroupInfo(folder :: any, GROUP_ID, { rank = 1, role = "Member" })
		end).toThrow("Not a PlayerMock")

		folder:Destroy()
	end)
end)
