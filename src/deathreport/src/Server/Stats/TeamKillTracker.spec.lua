--!strict
--[[
	@class TeamKillTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local TeamKillTracker = require("TeamKillTracker")
local TeamKillTrackerUtils = require("TeamKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newTrackedTeam(controller: any): (Team, TeamKillTracker.TeamKillTracker, IntValue)
	local team = controller.newTeam()
	local score = TeamKillTrackerUtils.create(controller.teamKillTrackerBinder)
	score.Parent = team

	return team, DeathReportTestUtils.awaitBound(controller.teamKillTrackerBinder, score), score
end

describe("TeamKillTracker", function()
	it("binds under a team and starts at zero", function()
		local controller = DeathReportTestUtils.setup()
		local team, tracker = newTrackedTeam(controller)

		expect(tracker:GetTeam()).toBe(team)
		expect(tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("counts kills scored by players on the team", function()
		local controller = DeathReportTestUtils.setup()
		local team, tracker = newTrackedTeam(controller)

		local killer = controller.newMock()
		controller.setTeam(killer, team)
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(tracker:GetKills()).toEqual(1)

		controller:Destroy()
	end)

	it("ignores kills scored by other teams", function()
		local controller = DeathReportTestUtils.setup()
		local _team, tracker = newTrackedTeam(controller)
		local otherTeam = controller.newTeam()

		local killer = controller.newMock()
		controller.setTeam(killer, otherTeam)
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("ignores kills scored by players without a team", function()
		local controller = DeathReportTestUtils.setup()
		local _team, tracker = newTrackedTeam(controller)

		local killer = controller.newMock()
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("ignores unattributed deaths", function()
		local controller = DeathReportTestUtils.setup()
		local team, tracker = newTrackedTeam(controller)

		local victim = controller.newMock()
		controller.setTeam(victim, team)
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid)

		expect(tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("stops counting once unbound", function()
		local controller = DeathReportTestUtils.setup()
		local team, _tracker, score = newTrackedTeam(controller)

		local killer = controller.newMock()
		controller.setTeam(killer, team)
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.teamKillTrackerBinder:Unbind(score)
		DeathReportTestUtils.awaitUnbound(controller.teamKillTrackerBinder, score)

		controller.kill(victimHumanoid, killer)

		expect(score.Value).toEqual(0)

		controller:Destroy()
	end)
end)
