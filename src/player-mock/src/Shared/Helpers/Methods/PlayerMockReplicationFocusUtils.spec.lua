--!strict
--[[
	@class PlayerMockReplicationFocusUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockReplicationFocusUtils = require("PlayerMockReplicationFocusUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockReplicationFocusUtils.getReplicationFocuses", function()
	it("is empty for a mock that never focused anything", function()
		local player = PlayerMock.new()

		expect(PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toEqual({})

		player:Destroy()
	end)

	it("returns the parts in the order they were added", function()
		local player = PlayerMock.new()
		local first = Instance.new("Part")
		local second = Instance.new("Part")

		PlayerMockReplicationFocusUtils.addReplicationFocus(player, first)
		PlayerMockReplicationFocusUtils.addReplicationFocus(player, second)

		expect(PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toEqual({ first, second })

		player:Destroy()
		first:Destroy()
		second:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockReplicationFocusUtils.getReplicationFocuses(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockReplicationFocusUtils.addReplicationFocus", function()
	it("backs a set, so adding a part already focused changes nothing", function()
		local player = PlayerMock.new()
		local part = Instance.new("Part")

		PlayerMockReplicationFocusUtils.addReplicationFocus(player, part)
		PlayerMockReplicationFocusUtils.addReplicationFocus(player, part)

		expect(PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toEqual({ part })

		player:Destroy()
		part:Destroy()
	end)

	it("keeps parts sharing a name distinct", function()
		local player = PlayerMock.new()
		local first = Instance.new("Part")
		first.Name = "Same"
		local second = Instance.new("Part")
		second.Name = "Same"

		PlayerMockReplicationFocusUtils.addReplicationFocus(player, first)
		PlayerMockReplicationFocusUtils.addReplicationFocus(player, second)

		expect(#PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toBe(2)

		player:Destroy()
		first:Destroy()
		second:Destroy()
	end)

	it("throws on something that is not a BasePart", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockReplicationFocusUtils.addReplicationFocus(player, Instance.new("Folder") :: any)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockReplicationFocusUtils.removeReplicationFocus", function()
	it("drops only the part given", function()
		local player = PlayerMock.new()
		local kept = Instance.new("Part")
		local dropped = Instance.new("Part")

		PlayerMockReplicationFocusUtils.addReplicationFocus(player, kept)
		PlayerMockReplicationFocusUtils.addReplicationFocus(player, dropped)
		PlayerMockReplicationFocusUtils.removeReplicationFocus(player, dropped)

		expect(PlayerMockReplicationFocusUtils.getReplicationFocuses(player)).toEqual({ kept })

		player:Destroy()
		kept:Destroy()
		dropped:Destroy()
	end)

	it("is a no-op for a part that is not focused", function()
		local player = PlayerMock.new()
		local part = Instance.new("Part")

		expect(function()
			PlayerMockReplicationFocusUtils.removeReplicationFocus(player, part)
		end).never.toThrow()

		player:Destroy()
		part:Destroy()
	end)
end)
