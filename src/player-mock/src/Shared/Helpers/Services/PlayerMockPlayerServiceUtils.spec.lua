--!strict
--[[
	@class PlayerMockPlayerServiceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockPlayerServiceUtils = require("PlayerMockPlayerServiceUtils")
local PlayerMockUtils = require("PlayerMockUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local controller = {
		newPlayer = function(userId: number): Player
			local player = PlayerMock.new({ UserId = userId })
			player.Parent = Workspace
			maid:GiveTask(player)
			return player
		end,
		designate = function(player: Player?): () -> ()
			local restore = PlayerMockPlayerServiceUtils.setMockedLocalPlayer(player)
			maid:GiveTask(restore)
			return restore
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerMockPlayerServiceUtils.getPlayerByUserId", function()
	it("finds the mock seeded with that UserId", function()
		local controller = setup()

		local player = controller.newPlayer(987654)

		expect(PlayerMockPlayerServiceUtils.getPlayerByUserId(987654)).toBe(player)

		controller:Destroy()
	end)

	it("is nil when no mock carries that UserId", function()
		expect(PlayerMockPlayerServiceUtils.getPlayerByUserId(987655)).toBeNil()
	end)

	it("is nil for a mock that never entered the DataModel", function()
		local player = PlayerMock.new({ UserId = 987656 })

		expect(PlayerMockPlayerServiceUtils.getPlayerByUserId(987656)).toBeNil()

		player:Destroy()
	end)

	it("throws on a non-number UserId", function()
		expect(function()
			PlayerMockPlayerServiceUtils.getPlayerByUserId("987654" :: any)
		end).toThrow()
	end)
end)

describe("PlayerMockPlayerServiceUtils.setMockedLocalPlayer", function()
	it("designates the mock the local player", function()
		local controller = setup()

		local player = controller.newPlayer(1)
		controller.designate(player)

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBe(player)

		controller:Destroy()
	end)

	it("designates only one mock at a time", function()
		local controller = setup()

		local first = controller.newPlayer(1)
		local second = controller.newPlayer(2)
		controller.designate(first)
		controller.designate(second)

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBe(second)

		controller:Destroy()
	end)

	it("clears the designation when passed nil", function()
		local controller = setup()

		controller.designate(controller.newPlayer(1))
		controller.designate(nil)

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBeNil()

		controller:Destroy()
	end)

	it("throws on something that is not a PlayerMock", function()
		local controller = setup()

		local folder = Instance.new("Folder")
		expect(function()
			PlayerMockPlayerServiceUtils.setMockedLocalPlayer(folder :: any)
		end).toThrow()
		folder:Destroy()

		controller:Destroy()
	end)

	it("throws on a mock that is not in the DataModel", function()
		local controller = setup()

		local player = PlayerMock.new()
		expect(function()
			PlayerMockPlayerServiceUtils.setMockedLocalPlayer(player)
		end).toThrow()
		player:Destroy()

		controller:Destroy()
	end)
end)

describe("PlayerMockPlayerServiceUtils.setMockedLocalPlayer disposer", function()
	it("clears the designation when there was none before", function()
		local controller = setup()

		local restore = controller.designate(controller.newPlayer(1))
		restore()

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBeNil()

		controller:Destroy()
	end)

	it("restores the previous designation", function()
		local controller = setup()

		local first = controller.newPlayer(1)
		controller.designate(first)
		local restoreSecond = controller.designate(controller.newPlayer(2))
		restoreSecond()

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBe(first)

		controller:Destroy()
	end)

	it("is safe to call more than once", function()
		local controller = setup()

		local restore = controller.designate(controller.newPlayer(1))
		restore()
		restore()

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBeNil()

		controller:Destroy()
	end)

	it("leaves a designation someone else made since", function()
		local controller = setup()

		local restoreFirst = controller.designate(controller.newPlayer(1))
		local second = controller.newPlayer(2)
		controller.designate(second)
		restoreFirst()

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBe(second)

		controller:Destroy()
	end)

	it("does not restore a previous mock that has left the DataModel", function()
		local controller = setup()

		local first = controller.newPlayer(1)
		controller.designate(first)
		local restoreSecond = controller.designate(controller.newPlayer(2))
		first.Parent = nil
		restoreSecond()

		expect(PlayerMockUtils.getMockedLocalPlayer()).toBeNil()

		controller:Destroy()
	end)
end)
