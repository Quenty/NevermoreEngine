--!strict
--[[
	Client binder coverage with both realms booted: the server binder tags every player and keeps the
	replicated value, and the client binder binds the same tagged player.

	@class PlayerKillTrackerClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerKillTrackerInterface = require("PlayerKillTrackerInterface")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local controller = DeathReportTestUtils.setup({ withClient = true })

	local mock = controller.newMock()
	controller.setLocalPlayer(mock)

	controller.mock = mock
	controller.score = DeathReportTestUtils.awaitBound(controller.playerKillTrackerBinder, mock):GetKillValue()
	controller.tracker = DeathReportTestUtils.awaitBound(controller.playerKillTrackerClientBinder, mock)

	return controller
end

describe("PlayerKillTrackerClient", function()
	it("binds the tagged player and reads its replicated kills", function()
		local controller = setup()

		expect(controller.tracker:GetPlayer()).toBe(controller.mock)
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

		controller.score.Value = 2

		expect(DeathReportTestUtils.waitFor(function()
			return #values == 1
		end)).toBe(true)
		expect(values[1]).toEqual(2)
		expect(controller.tracker:GetKills()).toEqual(2)

		controller:Destroy()
	end)

	it("sees kills the server counts for the player", function()
		local controller = setup()
		controller.newCharacter(controller.mock)

		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		controller.kill(victimHumanoid, controller.mock)

		expect(DeathReportTestUtils.waitFor(function()
			return controller.tracker:GetKills() == 1
		end)).toBe(true)

		controller:Destroy()
	end)

	it("implements PlayerKillTrackerInterface for the client realm", function()
		local controller = setup()

		local implementation = PlayerKillTrackerInterface.Client:Find(controller.mock)
		assert(implementation, "No implementation")

		expect(implementation:GetPlayer()).toBe(controller.mock)
		expect(implementation:GetKillValue()).toBe(controller.score)
		expect(implementation:GetKills()).toEqual(0)

		controller:Destroy()
	end)
end)
