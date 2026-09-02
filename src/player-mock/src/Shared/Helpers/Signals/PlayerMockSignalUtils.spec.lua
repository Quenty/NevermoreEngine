--!strict
--[[
	@class PlayerMockSignalUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockSignalUtils = require("PlayerMockSignalUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockSignalUtils.getSignal", function()
	it("returns a stand-in for an event only a real Player has", function()
		local player = PlayerMock.new()
		local seen = {}

		local connection = PlayerMockSignalUtils.getSignal(player, "Chatted"):Connect(function(message)
			table.insert(seen, message)
		end)
		PlayerMockSignalUtils.fireSignal(player, "Chatted", "hello")

		expect(seen).toEqual({ "hello" })

		connection:Disconnect()
		player:Destroy()
	end)

	it("returns the genuine signal for an event the backing Folder inherits from Instance", function()
		local player = PlayerMock.new()

		expect(PlayerMockSignalUtils.getSignal(player, "Destroying")).toBe((player :: Instance).Destroying)

		player:Destroy()
	end)

	it("returns one backing however many times it is asked", function()
		local player = PlayerMock.new()

		PlayerMockSignalUtils.getSignal(player, "Idled")
		PlayerMockSignalUtils.getSignal(player, "Idled")

		local backings = 0
		for _, child in (player :: Instance):GetChildren() do
			if child.Name == PlayerMockConstants.SIGNAL_NAME_PREFIX .. "Idled" then
				backings += 1
			end
		end

		expect(backings).toBe(1)

		player:Destroy()
	end)

	it("throws on an event name no Player has", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockSignalUtils.getSignal(player, "Chattd")
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockSignalUtils.fireSignal", function()
	it("delivers every argument to connected handlers", function()
		local player = PlayerMock.new()
		local seen = {}

		local connection = PlayerMockSignalUtils.getSignal(player, "Chatted"):Connect(function(message, recipient)
			table.insert(seen, { message = message, recipient = recipient })
		end)
		PlayerMockSignalUtils.fireSignal(player, "Chatted", "hello", player)

		expect(#seen).toBe(1)
		expect(seen[1].message).toBe("hello")
		expect(seen[1].recipient).toBe(player)

		connection:Disconnect()
		player:Destroy()
	end)

	it("is a no-op when nothing ever connected, so teardown cannot create a child", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockSignalUtils.fireSignal(player, "Idled", 5)
		end).never.toThrow()
		expect((player :: Instance):FindFirstChild(PlayerMockConstants.SIGNAL_NAME_PREFIX .. "Idled")).toBeNil()

		player:Destroy()
	end)

	it("throws on a native event only the engine can fire", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockSignalUtils.fireSignal(player, "Destroying")
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockSignalUtils service events", function()
	it("stands in for an event of a class the mock is not", function()
		local player = PlayerMock.new()
		local fired = 0

		local connection = PlayerMockSignalUtils.getSignal(player, "UserInputService.WindowFocused"):Connect(function()
			fired += 1
		end)
		PlayerMockSignalUtils.fireSignal(player, "UserInputService.WindowFocused")

		expect(fired).toBe(1)

		connection:Disconnect()
		player:Destroy()
	end)

	it("backs the event under a name flattened from the path", function()
		local player = PlayerMock.new()

		PlayerMockSignalUtils.getSignal(player, "UserInputService.WindowFocused")

		expect(
			(player :: Instance):FindFirstChild(
				PlayerMockConstants.SIGNAL_NAME_PREFIX .. "UserInputService_WindowFocused"
			)
		).never.toBeNil()

		player:Destroy()
	end)

	it("agrees between both forms of the path, so a connect and a fire cannot drift", function()
		local player = PlayerMock.new()
		local fired = 0

		local connection = PlayerMockSignalUtils.getSignal(player, { "UserInputService", "WindowFocused" })
			:Connect(function()
				fired += 1
			end)
		PlayerMockSignalUtils.fireSignal(player, "UserInputService.WindowFocused")

		expect(fired).toBe(1)

		connection:Disconnect()
		player:Destroy()
	end)

	it("keeps each mock's copy of the client-global event apart", function()
		local first = PlayerMock.new()
		local second = PlayerMock.new()
		local fired = 0

		local connection = PlayerMockSignalUtils.getSignal(second, "UserInputService.WindowFocused"):Connect(function()
			fired += 1
		end)
		PlayerMockSignalUtils.fireSignal(first, "UserInputService.WindowFocused")

		expect(fired).toBe(0)

		connection:Disconnect()
		first:Destroy()
		second:Destroy()
	end)

	it("leaves a Player event on its own unprefixed backing name", function()
		local player = PlayerMock.new()

		PlayerMockSignalUtils.getSignal(player, "Chatted")

		expect((player :: Instance):FindFirstChild(PlayerMockConstants.SIGNAL_NAME_PREFIX .. "Chatted")).never.toBeNil()

		player:Destroy()
	end)

	it("throws on a class the engine does not reflect", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockSignalUtils.getSignal(player, "NotARealService.WindowFocused")
		end).toThrow()

		player:Destroy()
	end)

	it("throws on a misspelled event of a real class", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockSignalUtils.getSignal(player, "UserInputService.WindowFocusd")
		end).toThrow()

		player:Destroy()
	end)

	it("throws on a path deeper than a service event", function()
		local player = PlayerMock.new()

		expect(function()
			PlayerMockSignalUtils.getSignal(player, "UserInputService.Window.Focused")
		end).toThrow()

		player:Destroy()
	end)
end)
