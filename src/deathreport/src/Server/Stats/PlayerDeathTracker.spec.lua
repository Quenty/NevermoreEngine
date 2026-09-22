--!strict
--[[
	@class PlayerDeathTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerDeathTracker = require("PlayerDeathTracker")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newTracker(controller: any, mock: Player): (PlayerDeathTracker.PlayerDeathTracker, IntValue)
	local score = PlayerKillTrackerUtils.create(controller.playerDeathTrackerBinder, mock)
	return DeathReportTestUtils.awaitBound(controller.playerDeathTrackerBinder, score), score
end

describe("PlayerDeathTracker", function()
	it("binds under the player and starts at zero", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local tracker, score = newTracker(controller, mock)

		expect(tracker:GetPlayer()).toBe(mock)
		expect(tracker:GetDeathValue()).toBe(score)
		expect(tracker:GetDeaths()).toEqual(0)

		controller:Destroy()
	end)

	it("counts the deaths of the player", function()
		local controller = DeathReportTestUtils.setup()
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local tracker = newTracker(controller, victim)

		controller.kill(victimHumanoid)

		expect(tracker:GetDeaths()).toEqual(1)

		controller:Destroy()
	end)

	it("counts attributed deaths of the player", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local tracker = newTracker(controller, victim)

		controller.kill(victimHumanoid, killer)

		expect(tracker:GetDeaths()).toEqual(1)

		controller:Destroy()
	end)

	it("does not count the kills the player scores", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local killerTracker = newTracker(controller, killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(killerTracker:GetDeaths()).toEqual(0)

		controller:Destroy()
	end)

	it("stops counting once unbound", function()
		local controller = DeathReportTestUtils.setup()
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local _tracker, score = newTracker(controller, victim)

		controller.playerDeathTrackerBinder:Unbind(score)
		DeathReportTestUtils.awaitUnbound(controller.playerDeathTrackerBinder, score)

		controller.kill(victimHumanoid)

		expect(score.Value).toEqual(0)

		controller:Destroy()
	end)
end)
