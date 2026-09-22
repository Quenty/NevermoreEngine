--!strict
--[[
	@class DeathTrackedHumanoid.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local DeathTrackedHumanoid = require("DeathTrackedHumanoid")
local Jest = require("Jest")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DeathTrackedHumanoid", function()
	it("binds the humanoid of a mock character", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.serverBag:GetService(DeathTrackedHumanoid)
		local mock = controller.newMock()
		local _character, humanoid = controller.newCharacter(mock)

		local class = binder:Get(humanoid)
		expect(class).toBeDefined()
		expect((class :: any).ClassName).toEqual("DeathTrackedHumanoid")

		controller:Destroy()
	end)

	it("unbinds when the character is removed", function()
		local controller = DeathReportTestUtils.setup()
		local binder = controller.serverBag:GetService(DeathTrackedHumanoid)
		local mock = controller.newMock()
		local _character, humanoid = controller.newCharacter(mock)

		PlayerMock.removeCharacter(mock)
		DeathReportTestUtils.awaitUnbound(binder, humanoid)

		expect(binder:Get(humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("reports the death to the service exactly once", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local _character, humanoid = controller.newCharacter(mock)

		local reportCount = 0
		controller.maid:GiveTask(controller.deathReportService.NewDeathReport:Connect(function()
			reportCount += 1
		end))

		humanoid.Health = 0
		expect(reportCount).toEqual(1)

		humanoid.Health = 100
		humanoid.Health = 0
		expect(reportCount).toEqual(1)

		controller:Destroy()
	end)

	it("does not report while the humanoid is alive", function()
		local controller = DeathReportTestUtils.setup()
		local mock = controller.newMock()
		local _character, humanoid = controller.newCharacter(mock)

		local reportCount = 0
		controller.maid:GiveTask(controller.deathReportService.NewDeathReport:Connect(function()
			reportCount += 1
		end))

		humanoid.Health = 50
		humanoid.Health = 1
		expect(reportCount).toEqual(0)

		controller:Destroy()
	end)
end)
