--!strict
--[[
	@class PlayerKillTrackerAssigner.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerKillTrackerAssigner = require("PlayerKillTrackerAssigner")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function newAssigner(controller: any): PlayerKillTrackerAssigner.PlayerKillTrackerAssigner
	return controller.maid:Add(PlayerKillTrackerAssigner.new(controller.serverBag))
end

local function awaitTrackers(controller: any, assigner: any, mock: Player): boolean
	return DeathReportTestUtils.waitFor(function()
		return assigner:GetPlayerKillTracker(mock) ~= nil
			and PlayerKillTrackerUtils.getPlayerKillTracker(controller.playerDeathTrackerBinder, mock) ~= nil
	end)
end

describe("PlayerKillTrackerAssigner", function()
	it("assigns kill and death trackers to players already present", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()

		local assigner = newAssigner(controller)

		expect(awaitTrackers(controller, assigner, mock)).toBe(true)
		expect(assigner:GetPlayerKills(mock)).toEqual(0)
		expect(PlayerKillTrackerUtils.getPlayerKillTracker(controller.playerKillTrackerBinder, mock)).toBe(
			assigner:GetPlayerKillTracker(mock)
		)

		controller:Destroy()
	end)

	it("assigns trackers to players who join later", function()
		local controller = DeathReportTestUtils.setup()
		local assigner = newAssigner(controller)

		local mock = controller.newMock()

		expect(awaitTrackers(controller, assigner, mock)).toBe(true)
		expect(assigner:GetPlayerKills(mock)).toEqual(0)

		controller:Destroy()
	end)

	it("counts kills through the assigned tracker", function()
		local controller = DeathReportTestUtils.setup()
		local assigner = newAssigner(controller)

		local killer = controller.newMock()
		controller.newCharacter(killer)
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		expect(awaitTrackers(controller, assigner, killer)).toBe(true)
		expect(awaitTrackers(controller, assigner, victim)).toBe(true)

		controller.kill(victimHumanoid, killer)

		expect(assigner:GetPlayerKills(killer)).toEqual(1)
		expect(assigner:GetPlayerKills(victim)).toEqual(0)

		local victimDeathTracker =
			PlayerKillTrackerUtils.getPlayerKillTracker(controller.playerDeathTrackerBinder, victim)
		expect(assert(victimDeathTracker, "No death tracker"):GetDeaths()).toEqual(1)

		controller:Destroy()
	end)

	it("returns nil for a player it has not seen", function()
		local controller = DeathReportTestUtils.setup()
		local assigner = newAssigner(controller)

		-- Never parented, so it never joins
		local stranger = PlayerMock.new()
		controller.maid:GiveTask(stranger)

		expect(assigner:GetPlayerKills(stranger)).toBeNil()
		expect(assigner:GetPlayerKillTracker(stranger)).toBeNil()

		controller:Destroy()
	end)

	it("removes the trackers when destroyed", function()
		local controller = DeathReportTestUtils.setup()
		local assigner = PlayerKillTrackerAssigner.new(controller.serverBag)
		local mock = controller.newMock()

		expect(awaitTrackers(controller, assigner, mock)).toBe(true)

		assigner:Destroy()

		expect(mock:FindFirstChildWhichIsA("IntValue")).toBeNil()

		controller:Destroy()
	end)

	it("removes the trackers when the player leaves", function()
		local controller = DeathReportTestUtils.setup()
		local assigner = newAssigner(controller)
		local mock = controller.newMock()

		expect(awaitTrackers(controller, assigner, mock)).toBe(true)

		mock:Destroy()

		expect(DeathReportTestUtils.waitFor(function()
			return assigner:GetPlayerKillTracker(mock) == nil
		end)).toBe(true)

		controller:Destroy()
	end)

	it("requires a service bag", function()
		expect(function()
			PlayerKillTrackerAssigner.new(nil :: any)
		end).toThrow()
	end)
end)
