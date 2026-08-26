--!strict
--[[
	@class PlayerMockUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockUtils = require("PlayerMockUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Sentinel standing in for a nil emission, so emissions can live in an array
local NONE = "none"

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
		subscribeSeen = function(): { any }
			local seen: { any } = {}
			maid:GiveTask(PlayerMockUtils.observeMockedLocalPlayer():Subscribe(function(localPlayer: Player?)
				table.insert(seen, if localPlayer ~= nil then localPlayer else NONE)
			end))
			return seen
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("PlayerMockUtils.observeMockedLocalPlayer", function()
	it("emits the current designation on subscribe", function()
		local controller = setup()

		local player = controller.newPlayer()
		controller.designate(player)

		expect(controller.subscribeSeen()).toEqual({ player })

		controller.destroy()
	end)

	it("emits nil on subscribe when nothing is designated", function()
		local controller = setup()

		expect(controller.subscribeSeen()).toEqual({ NONE })

		controller.destroy()
	end)

	it("follows the designation changing after subscribe", function()
		local controller = setup()

		local player = controller.newPlayer()
		local seen = controller.subscribeSeen()

		controller.designate(player)
		expect(seen[#seen]).toBe(player)

		PlayerMock.setMockedLocalPlayer(nil)
		expect(seen[#seen]).toBe(NONE)

		controller.destroy()
	end)
end)
