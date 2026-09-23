--!strict
--[[
	@class PlayerDeathTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportServiceConstants = require("DeathReportServiceConstants")
local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerDeathTracker = require("PlayerDeathTracker")
local PlayerDeathTrackerInterface = require("PlayerDeathTrackerInterface")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function awaitTracker(controller: any, mock: Player): PlayerDeathTracker.PlayerDeathTracker
	return DeathReportTestUtils.awaitBound(controller.playerDeathTrackerBinder, mock)
end

describe("PlayerDeathTracker", function()
	it("binds to every player and starts at zero", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local tracker = awaitTracker(controller, mock)

		expect(tracker:GetPlayer()).toBe(mock)
		expect(tracker:GetDeaths()).toEqual(0)

		local deathValue = tracker:GetDeathValue()
		expect(deathValue.Parent).toBe(mock)
		expect(deathValue.Name).toEqual(DeathReportServiceConstants.PLAYER_DEATH_VALUE_NAME)
		expect(deathValue.Value).toEqual(0)

		controller:Destroy()
	end)

	it("counts the deaths of the player", function()
		local controller = DeathReportTestUtils.setup()
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local tracker = awaitTracker(controller, victim)

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
		local tracker = awaitTracker(controller, victim)

		controller.kill(victimHumanoid, killer)

		expect(tracker:GetDeaths()).toEqual(1)

		controller:Destroy()
	end)

	it("does not count the kills the player scores", function()
		local controller = DeathReportTestUtils.setup()
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local killerTracker = awaitTracker(controller, killer)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, killer)

		expect(killerTracker:GetDeaths()).toEqual(0)

		controller:Destroy()
	end)

	it("removes its value once unbound", function()
		local controller = DeathReportTestUtils.setup()
		local victim = controller.newMock()
		local deathValue = awaitTracker(controller, victim):GetDeathValue()

		controller.playerDeathTrackerBinder:Unbind(victim)
		DeathReportTestUtils.awaitUnbound(controller.playerDeathTrackerBinder, victim)

		expect(deathValue.Parent).toBeNil()
		expect(victim:FindFirstChild(DeathReportServiceConstants.PLAYER_DEATH_VALUE_NAME)).toBeNil()

		controller:Destroy()
	end)

	it("implements PlayerDeathTrackerInterface on the player", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local tracker = awaitTracker(controller, mock)

		local implementation = PlayerDeathTrackerInterface.Server:Find(mock)
		assert(implementation, "No implementation")

		expect(implementation:GetPlayer()).toBe(mock)
		expect(implementation:GetDeathValue()).toBe(tracker:GetDeathValue())
		expect(implementation:GetDeaths()).toEqual(0)

		controller:Destroy()
	end)
end)
