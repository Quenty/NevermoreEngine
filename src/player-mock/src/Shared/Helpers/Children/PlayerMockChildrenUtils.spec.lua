--!strict
--[[
	@class PlayerMockChildrenUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockChildrenUtils = require("PlayerMockChildrenUtils")
local PlayerMockConstants = require("PlayerMockConstants")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockChildrenUtils.seedContainers", function()
	it("leaves a fresh mock holding the PlayerGui and PlayerScripts stand-ins", function()
		local player = PlayerMock.new()

		expect(PlayerMockChildrenUtils.getPlayerGui(player).Name).toBe(PlayerMockConstants.PLAYER_GUI_NAME)
		expect(PlayerMockChildrenUtils.getPlayerScripts(player).Name).toBe(PlayerMockConstants.PLAYER_SCRIPTS_NAME)

		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockChildrenUtils.seedContainers(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockChildrenUtils.getPlayerGui", function()
	it("throws when the container is missing rather than answering nil", function()
		local player = PlayerMock.new()
		PlayerMockChildrenUtils.getPlayerGui(player):Destroy()

		expect(function()
			PlayerMockChildrenUtils.getPlayerGui(player)
		end).toThrow()

		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockChildrenUtils.getPlayerGui(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockChildrenUtils.getPlayerScripts", function()
	it("throws when the container is missing rather than answering nil", function()
		local player = PlayerMock.new()
		PlayerMockChildrenUtils.getPlayerScripts(player):Destroy()

		expect(function()
			PlayerMockChildrenUtils.getPlayerScripts(player)
		end).toThrow()

		player:Destroy()
	end)
end)

describe("PlayerMockChildrenUtils.getBackpack", function()
	it("is nil before the first spawn", function()
		local player = PlayerMock.new()

		expect(PlayerMockChildrenUtils.getBackpack(player)).toBeNil()

		player:Destroy()
	end)

	it("returns the Backpack a spawn parented into the mock", function()
		local player = PlayerMock.new()
		local backpack = Instance.new("Backpack")
		backpack.Parent = player :: Instance

		expect(PlayerMockChildrenUtils.getBackpack(player)).toBe(backpack)

		player:Destroy()
	end)

	it("throws when passed something that is not a PlayerMock", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerMockChildrenUtils.getBackpack(folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)

describe("PlayerMockChildrenUtils.getStarterGear", function()
	it("is nil before the first spawn", function()
		local player = PlayerMock.new()

		expect(PlayerMockChildrenUtils.getStarterGear(player)).toBeNil()

		player:Destroy()
	end)

	it("returns the StarterGear a spawn parented into the mock", function()
		local player = PlayerMock.new()
		local starterGear = Instance.new("StarterGear")
		starterGear.Parent = player :: Instance

		expect(PlayerMockChildrenUtils.getStarterGear(player)).toBe(starterGear)

		player:Destroy()
	end)
end)
