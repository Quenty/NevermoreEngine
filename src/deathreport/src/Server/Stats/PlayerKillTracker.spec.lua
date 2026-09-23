--!strict
--[[
	@class PlayerKillTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerKillTracker = require("PlayerKillTracker")
local PlayerKillTrackerInterface = require("PlayerKillTrackerInterface")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function awaitTracker(controller: any, mock: Player): PlayerKillTracker.PlayerKillTracker
	return DeathReportTestUtils.awaitBound(controller.playerKillTrackerBinder, mock)
end

describe("PlayerKillTracker", function()
	it("binds to every player and starts at zero", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local tracker = awaitTracker(controller, mock)

		expect(tracker:GetPlayer()).toBe(mock)
		expect(tracker:GetKills()).toEqual(0)

		local killValue = tracker:GetKillValue()
		expect(killValue.Parent).toBe(mock)
		expect(killValue.Name).toEqual(DeathReportServiceConstants.PLAYER_KILL_VALUE_NAME)
		expect(killValue.Value).toEqual(0)

		controller:Destroy()
	end)

	it("counts the kills the player scores", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local tracker = awaitTracker(controller, killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(tracker:GetKills()).toEqual(1)

		controller:Destroy()
	end)

	it("does not count the deaths of the player", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local victimTracker = awaitTracker(controller, victim)

		controller.kill(victimHumanoid, killer)

		expect(victimTracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("does not count kills scored by other players", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)

		local bystander = controller.newMock()
		local bystanderTracker = awaitTracker(controller, bystander)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(bystanderTracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("removes its value once unbound", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local killValue = awaitTracker(controller, killer):GetKillValue()

		controller.playerKillTrackerBinder:Unbind(killer)
		DeathReportTestUtils.awaitUnbound(controller.playerKillTrackerBinder, killer)

		expect(killValue.Parent).toBeNil()
		expect(killer:FindFirstChild(DeathReportServiceConstants.PLAYER_KILL_VALUE_NAME)).toBeNil()

		controller:Destroy()
	end)

	it("implements PlayerKillTrackerInterface on the player", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local tracker = awaitTracker(controller, mock)

		local implementation = PlayerKillTrackerInterface.Server:Find(mock)
		assert(implementation, "No implementation")

		expect(implementation:GetPlayer()).toBe(mock)
		expect(implementation:GetKillValue()).toBe(tracker:GetKillValue())
		expect(implementation:GetKills()).toEqual(0)

		controller:Destroy()
	end)
end)
