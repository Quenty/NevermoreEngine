--!strict
--[[
	@class PlayerMockCoreGuiUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockCoreGuiUtils = require("PlayerMockCoreGuiUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockCoreGuiUtils.getCoreEvent", function()
	it("answers the same event however many times it is asked", function()
		local player = PlayerMock.new()

		local first = PlayerMockCoreGuiUtils.getCoreEvent(player, "PlayerFriendedEvent")
		local second = PlayerMockCoreGuiUtils.getCoreEvent(player, "PlayerFriendedEvent")

		expect(first).toBe(second)

		player:Destroy()
	end)

	it("keeps the friended and unfriended events apart", function()
		local player = PlayerMock.new()
		local friended = 0
		local unfriended = 0

		local friendedConnection = PlayerMockCoreGuiUtils.getCoreEvent(player, "PlayerFriendedEvent").Event
			:Connect(function()
				friended += 1
			end)
		local unfriendedConnection = PlayerMockCoreGuiUtils.getCoreEvent(player, "PlayerUnfriendedEvent").Event
			:Connect(function()
				unfriended += 1
			end)

		PlayerMockCoreGuiUtils.getCoreEvent(player, "PlayerFriendedEvent"):Fire()

		expect(friended).toBe(1)
		expect(unfriended).toBe(0)

		friendedConnection:Disconnect()
		unfriendedConnection:Disconnect()
		player:Destroy()
	end)

	it("keeps each mock's events its own", function()
		local first = PlayerMock.new()
		local second = PlayerMock.new()

		expect(PlayerMockCoreGuiUtils.getCoreEvent(first, "PlayerFriendedEvent")).never.toBe(
			PlayerMockCoreGuiUtils.getCoreEvent(second, "PlayerFriendedEvent")
		)

		first:Destroy()
		second:Destroy()
	end)

	it("errors for a core it models no stand-in for", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockCoreGuiUtils.getCoreEvent(player, "DevConsoleVisible")
		end).toThrow()

		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockCoreGuiUtils.getCoreEvent(folder :: any, "PlayerFriendedEvent")
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("the StarterGui.GetCore domain", function()
	it("answers a call with the mock's own core event", function()
		local player = PlayerMock.new()

		expect(PlayerMock.callMethod(player, "StarterGui.GetCore", "PlayerFriendedEvent")).toBe(
			PlayerMockCoreGuiUtils.getCoreEvent(player, "PlayerFriendedEvent")
		)

		player:Destroy()
	end)
end)
