--!strict
--[[
	@class PlayerMockUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockUtils = require("PlayerMockUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local afterEach = Jest.Globals.afterEach

-- Sentinel standing in for a nil emission, so emissions can live in an array
local NONE = "none"

local function subscribeSeen(maid: Maid.Maid): { any }
	local seen: { any } = {}
	maid:GiveTask(PlayerMockUtils.observeMockedLocalPlayer():Subscribe(function(localPlayer: Player?)
		table.insert(seen, if localPlayer ~= nil then localPlayer else NONE)
	end))
	return seen
end

describe("PlayerMockUtils.observeMockedLocalPlayer", function()
	afterEach(function()
		PlayerMock.setMockedLocalPlayer(nil)
	end)

	it("emits the current designation on subscribe", function()
		local player = PlayerMock.new({ UserId = 1 })
		player.Parent = Workspace
		PlayerMock.setMockedLocalPlayer(player)

		local maid = Maid.new()
		local seen = subscribeSeen(maid)

		expect(seen).toEqual({ player })

		maid:DoCleaning()
		player:Destroy()
	end)

	it("emits nil on subscribe when nothing is designated", function()
		local maid = Maid.new()
		local seen = subscribeSeen(maid)

		expect(seen).toEqual({ NONE })

		maid:DoCleaning()
	end)

	it("follows the designation changing after subscribe", function()
		local player = PlayerMock.new({ UserId = 1 })
		player.Parent = Workspace

		local maid = Maid.new()
		local seen = subscribeSeen(maid)

		PlayerMock.setMockedLocalPlayer(player)
		expect(seen[#seen]).toBe(player)

		PlayerMock.setMockedLocalPlayer(nil)
		expect(seen[#seen]).toBe(NONE)

		maid:DoCleaning()
		player:Destroy()
	end)
end)
