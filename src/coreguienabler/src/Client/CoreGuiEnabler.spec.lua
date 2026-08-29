--!strict
--[[
	@class CoreGuiEnabler.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local CoreGuiEnabler = require("CoreGuiEnabler")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setupLocalPlayer(): Player
	local maid = Maid.new()
	JestUtils.afterThis(maid)

	local player = PlayerMock.new({ UserId = 66123001 })
	player.Parent = Workspace
	local restoreLocalPlayer = PlayerMock.setMockedLocalPlayer(player)

	maid:GiveTask(function()
		restoreLocalPlayer()
		player:Destroy()
	end)

	return player
end

describe("CoreGuiEnabler.Disable", function()
	it("records the disable on the mocked local player and restores on enable", function()
		local player = setupLocalPlayer()
		local key = {}

		CoreGuiEnabler:Disable(key, Enum.CoreGuiType.Backpack)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack)).toBe(false)

		CoreGuiEnabler:Enable(key, Enum.CoreGuiType.Backpack)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Backpack)).toBe(true)
	end)

	it("keeps the state disabled while any key still holds it", function()
		local player = setupLocalPlayer()
		local keyA = {}
		local keyB = {}

		CoreGuiEnabler:Disable(keyA, Enum.CoreGuiType.Health)
		CoreGuiEnabler:Disable(keyB, Enum.CoreGuiType.Health)

		CoreGuiEnabler:Enable(keyA, Enum.CoreGuiType.Health)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Health)).toBe(false)
		expect(CoreGuiEnabler:IsEnabled(Enum.CoreGuiType.Health)).toBe(false)

		CoreGuiEnabler:Enable(keyB, Enum.CoreGuiType.Health)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.Health)).toBe(true)
		expect(CoreGuiEnabler:IsEnabled(Enum.CoreGuiType.Health)).toBe(true)
	end)

	it("returns a cleanup callback that re-enables the state", function()
		local player = setupLocalPlayer()

		local cleanup = CoreGuiEnabler:Disable({}, Enum.CoreGuiType.PlayerList)
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.PlayerList)).toBe(false)

		cleanup()
		expect(PlayerMock.readLookup(player, "StarterGui.SetCoreGuiEnabled", Enum.CoreGuiType.PlayerList)).toBe(true)
	end)

	it("errors on an unknown state", function()
		setupLocalPlayer()

		expect(function()
			CoreGuiEnabler:Disable({}, "never_added_state")
		end).toThrow()
	end)
end)

describe("CoreGuiEnabler.ObserveIsEnabled", function()
	it("emits the current state immediately and again on change", function()
		setupLocalPlayer()
		local key = {}
		local seen = {}

		local sub = CoreGuiEnabler:ObserveIsEnabled(Enum.CoreGuiType.EmotesMenu):Subscribe(function(isEnabled)
			table.insert(seen, isEnabled)
		end)

		CoreGuiEnabler:Disable(key, Enum.CoreGuiType.EmotesMenu)
		CoreGuiEnabler:Enable(key, Enum.CoreGuiType.EmotesMenu)

		expect(seen).toEqual({ true, false, true })

		sub:Destroy()
	end)
end)
