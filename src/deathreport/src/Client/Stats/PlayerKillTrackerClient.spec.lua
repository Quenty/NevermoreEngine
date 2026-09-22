--!strict
--[[
	Client binder coverage with both realms booted: the server binds the tracker it created, and the
	client binder binds the same replicated IntValue.

	@class PlayerKillTrackerClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local controller = DeathReportTestUtils.setup({ withClient = true })

	local mock = controller.newMock()
	controller.setLocalPlayer(mock)
	local score = PlayerKillTrackerUtils.create(controller.playerKillTrackerBinder, mock)

	controller.mock = mock
	controller.score = score
	controller.tracker = DeathReportTestUtils.awaitBound(controller.playerKillTrackerClientBinder, score)

	return controller
end

describe("PlayerKillTrackerClient", function()
	it("binds the replicated tracker and reads its player and kills", function()
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
end)
