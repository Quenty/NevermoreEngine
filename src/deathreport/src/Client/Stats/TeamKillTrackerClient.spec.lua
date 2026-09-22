--!strict
--[[
	Client binder coverage with both realms booted: the server binds the tracker it created, and the
	client binder binds the same replicated IntValue.

	@class TeamKillTrackerClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local TeamKillTrackerUtils = require("TeamKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local controller = DeathReportTestUtils.setup({ withClient = true })

	local team = controller.newTeam()
	local score = TeamKillTrackerUtils.create(controller.teamKillTrackerBinder)
	score.Parent = team

	controller.team = team
	controller.score = score
	controller.tracker = DeathReportTestUtils.awaitBound(controller.teamKillTrackerClientBinder, score)

	return controller
end

describe("TeamKillTrackerClient", function()
	it("binds the replicated tracker and reads its team and kills", function()
		local controller = setup()

		expect(controller.tracker:GetTeam()).toBe(controller.team)
		expect(controller.tracker:GetKillValue()).toBe(controller.score)
		expect(controller.tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("fires KillsChanged when the value changes", function()
		local controller = setup()

		local values = {}
		controller.maid:GiveTask(controller.tracker.KillsChanged:Connect(function(value: number)
			table.insert(values, value)
		end))

		controller.score.Value = 3

		expect(DeathReportTestUtils.waitFor(function()
			return #values == 1
		end)).toBe(true)
		expect(values[1]).toEqual(3)
		expect(controller.tracker:GetKills()).toEqual(3)

		controller:Destroy()
	end)

	it("sees kills the server counts for the team", function()
		local controller = setup()

		local killer = controller.newMock()
		controller.setTeam(killer, controller.team)
		controller.newCharacter(killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(DeathReportTestUtils.waitFor(function()
			return controller.tracker:GetKills() == 1
		end)).toBe(true)

		controller:Destroy()
	end)
end)
