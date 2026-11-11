--!strict
--[[
	@class TeamKillTrackerUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local TeamKillTrackerUtils = require("TeamKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("TeamKillTrackerUtils.create(binder)", function()
	it("returns an unparented zeroed value tagged for the binder", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.teamKillTrackerBinder

		local score = TeamKillTrackerUtils.create(binder)
		controller.maid:GiveTask(score)

		expect(score.Name).toEqual("TeamKillTracker")
		expect(score.Value).toEqual(0)
		expect(score.Parent).toBeNil()
		expect(binder:HasTag(score)).toBe(true)

		controller:Destroy()
	end)

	it("binds once parented under a team", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.teamKillTrackerBinder
		local team = controller.newTeam()

		local score = TeamKillTrackerUtils.create(binder)
		score.Parent = team

		local tracker = DeathReportTestUtils.awaitBound(binder, score)
		expect(tracker:GetTeam()).toBe(team)

		controller:Destroy()
	end)
end)

describe("TeamKillTrackerUtils.getTeamKillTracker(binder, team)", function()
	it("finds the bound tracker under the team", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.teamKillTrackerBinder
		local team = controller.newTeam()

		expect(TeamKillTrackerUtils.getTeamKillTracker(binder, team)).toBeNil()

		local score = TeamKillTrackerUtils.create(binder)
		score.Parent = team
		local tracker = DeathReportTestUtils.awaitBound(binder, score)

		expect(TeamKillTrackerUtils.getTeamKillTracker(binder, team)).toBe(tracker)

		controller:Destroy()
	end)
end)

describe("TeamKillTrackerUtils.observeBrio(binder, team)", function()
	it("emits the bound tracker and kills the brio when it is removed", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.teamKillTrackerBinder
		local team = controller.newTeam()

		local brios: { Brio.Brio<any> } = {}
		controller.maid:GiveTask(TeamKillTrackerUtils.observeBrio(binder, team):Subscribe(function(brio)
			table.insert(brios, brio)
		end))

		local score = TeamKillTrackerUtils.create(binder)
		score.Parent = team
		local tracker = DeathReportTestUtils.awaitBound(binder, score)

		expect(DeathReportTestUtils.waitFor(function()
			return #brios == 1
		end)).toBe(true)
		expect(brios[1]:GetValue()).toBe(tracker)
		expect(brios[1]:IsDead()).toBe(false)

		score:Destroy()

		expect(DeathReportTestUtils.waitFor(function()
			return brios[1]:IsDead()
		end)).toBe(true)

		controller:Destroy()
	end)

	it("rejects a non-instance", function()
		expect(function()
			TeamKillTrackerUtils.observeBrio(nil :: any, {} :: any)
		end).toThrow()
	end)
end)
