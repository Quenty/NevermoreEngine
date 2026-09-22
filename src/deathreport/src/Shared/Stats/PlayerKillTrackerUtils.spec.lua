--!strict
--[[
	@class PlayerKillTrackerUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local DeathReportTestUtils = require("DeathReportTestUtils")
local Jest = require("Jest")
local PlayerKillTrackerUtils = require("PlayerKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerKillTrackerUtils.create(binder, player)", function()
	it("binds a zeroed value under the player", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.playerKillTrackerBinder
		local mock = controller.newMock()

		local score = PlayerKillTrackerUtils.create(binder, mock)

		expect(score.Name).toEqual("PlayerKillTracker")
		expect(score.Value).toEqual(0)
		expect(score.Parent).toBe(mock)
		expect(binder:HasTag(score)).toBe(true)

		local tracker = DeathReportTestUtils.awaitBound(binder, score)
		expect(tracker:GetPlayer()).toBe(mock)

		controller:Destroy()
	end)

	it("rejects a non-instance player", function()
		expect(function()
			PlayerKillTrackerUtils.create(nil :: any, {} :: any)
		end).toThrow()
	end)
end)

describe("PlayerKillTrackerUtils.getPlayerKillTracker(binder, player)", function()
	it("finds the bound tracker under the player", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.playerKillTrackerBinder
		local mock = controller.newMock()

		expect(PlayerKillTrackerUtils.getPlayerKillTracker(binder, mock)).toBeNil()

		local score = PlayerKillTrackerUtils.create(binder, mock)
		local tracker = DeathReportTestUtils.awaitBound(binder, score)

		expect(PlayerKillTrackerUtils.getPlayerKillTracker(binder, mock)).toBe(tracker)

		controller:Destroy()
	end)
end)

describe("PlayerKillTrackerUtils.observeBrio(binder, player)", function()
	it("emits the bound tracker and kills the brio when it is removed", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.playerKillTrackerBinder
		local mock = controller.newMock()

		local brios: { Brio.Brio<any> } = {}
		controller.maid:GiveTask(PlayerKillTrackerUtils.observeBrio(binder, mock):Subscribe(function(brio)
			table.insert(brios, brio)
		end))

		local score = PlayerKillTrackerUtils.create(binder, mock)
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

	it("rejects a non-player", function()
		local folder = Instance.new("Folder")

		expect(function()
			PlayerKillTrackerUtils.observeBrio(nil :: any, folder :: any)
		end).toThrow()

		folder:Destroy()
	end)
end)
