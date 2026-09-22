--!strict
--[[
	@class PlayerKillTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerKillTracker = require("PlayerKillTracker")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newTracker(controller: any, mock: Player): (PlayerKillTracker.PlayerKillTracker, IntValue)
	local score = PlayerKillTrackerUtils.create(controller.playerKillTrackerBinder, mock)
	return DeathReportTestUtils.awaitBound(controller.playerKillTrackerBinder, score), score
end

describe("PlayerKillTracker", function()
	it("binds under the player and starts at zero", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local tracker, score = newTracker(controller, mock)

		expect(tracker:GetPlayer()).toBe(mock)
		expect(tracker:GetKillValue()).toBe(score)
		expect(tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("counts the kills the player scores", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local tracker = newTracker(controller, killer)

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
		local victimTracker = newTracker(controller, victim)

		controller.kill(victimHumanoid, killer)

		expect(victimTracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("does not count kills scored by other players", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)

		local bystander = controller.newMock()
		local bystanderTracker = newTracker(controller, bystander)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(bystanderTracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("stops counting once unbound", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local _tracker, score = newTracker(controller, killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.playerKillTrackerBinder:Unbind(score)
		DeathReportTestUtils.awaitUnbound(controller.playerKillTrackerBinder, score)

		controller.kill(victimHumanoid, killer)

		expect(score.Value).toEqual(0)

		controller:Destroy()
	end)
end)
