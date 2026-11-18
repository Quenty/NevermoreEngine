--!strict
--[[
	@class PlayerMockUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local PlayerMockUtils = require("PlayerMockUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local controller = {
		newPlayer = function(): Player
			local player = PlayerMock.new({ UserId = 1 })
			player.Parent = Workspace
			maid:GiveTask(player)
			return player
		end,
		designate = function(player: Player?)
			maid:GiveTask(PlayerMock.setMockedLocalPlayer(player))
		end,
		subscribeSeen = function(): ObservableSpy.ObservableSpy<Player?>
			return maid:Add(ObservableSpy.new(PlayerMockUtils.observeMockedLocalPlayer()))
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerMockUtils.observeMockedLocalPlayer", function()
	it("emits the current designation on subscribe", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designate(player)

		expect(controller.subscribeSeen().Values).toEqual({ player })

		controller:Destroy()
	end)

	it("emits nil on subscribe when nothing is designated", function()
		local controller = setup()

		local seen = controller.subscribeSeen()

		expect(#seen).toBe(1)
		expect(seen[1]).toBeNil()

		controller:Destroy()
	end)

	it("follows the designation changing after subscribe", function()
		local controller = setup()

		local player = controller.newPlayer()
		local seen = controller.subscribeSeen()

		controller.designate(player)
		expect(seen:GetLastValue()).toBe(player)

		PlayerMock.setMockedLocalPlayer(nil)
		expect(seen:GetLastValue()).toBeNil()

		controller:Destroy()
	end)
end)
