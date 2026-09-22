--!strict
--[[
	Client binder coverage with both realms booted: the server binds the tracker it created, and the
	client binder binds the same replicated IntValue.

	@class PlayerDeathTrackerClient.spec.lua
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
	local score = PlayerKillTrackerUtils.create(controller.playerDeathTrackerBinder, mock)

	controller.mock = mock
	controller.score = score
	controller.tracker = DeathReportTestUtils.awaitBound(controller.playerDeathTrackerClientBinder, score)

	return controller
end

describe("PlayerDeathTrackerClient", function()
	it("binds the replicated tracker and reads its player and deaths", function()
		local controller = setup()

		expect(controller.tracker:GetPlayer()).toBe(controller.mock)
		expect(controller.tracker:GetDeathValue()).toBe(controller.score)
		expect(controller.tracker:GetDeaths()).toEqual(0)
		expect(controller.tracker:GetKills()).toEqual(0)

		controller:Destroy()
	end)

	it("fires DeathsChanged when the value changes", function()
		local controller = setup()

		local values = {}
		controller.maid:GiveTask(controller.tracker.DeathsChanged:Connect(function(value: number)
			table.insert(values, value)
		end))

		controller.score.Value = 4

		expect(DeathReportTestUtils.waitFor(function()
			return #values == 1
		end)).toBe(true)
		expect(values[1]).toEqual(4)
		expect(controller.tracker:GetDeaths()).toEqual(4)

		controller:Destroy()
	end)

	it("sees deaths the server counts for the player", function()
		local controller = setup()
		local _character, humanoid = controller.newCharacter(controller.mock)

		controller.kill(humanoid)

		expect(DeathReportTestUtils.waitFor(function()
			return controller.tracker:GetDeaths() == 1
		end)).toBe(true)

		controller:Destroy()
	end)
end)
