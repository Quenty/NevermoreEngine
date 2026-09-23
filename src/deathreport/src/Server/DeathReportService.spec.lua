--!strict
--[[
	Coverage for DeathReportService booted headless against PlayerMocks. Deaths are driven the way
	production drives them: a mock character is spawned, DeathTrackedHumanoid binds its humanoid, the
	killer is tagged with the legacy creator tag, and the humanoid's health is set to zero.

	@class DeathReportService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportDataService = require("DeathReportDataService")
local DeathReportTestUtils = require("DeathReportTestUtils")
local DeathReportUtils = require("DeathReportUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function collectReports(controller: any): { DeathReportUtils.DeathReport }
	local reports: { DeathReportUtils.DeathReport } = {}
	controller.maid:GiveTask(controller.deathReportService.NewDeathReport:Connect(function(report)
		table.insert(reports, report)
	end))
	return reports
end

local function collect(controller: any, observable: any): { any }
	local emissions = {}
	controller.maid:GiveTask(observable:Subscribe(function(value)
		table.insert(emissions, value)
	end))
	return emissions
end

describe("DeathReportService.NewDeathReport", function()
	it("reports a tracked humanoid death with its tagged killer", function()
		local controller = DeathReportTestUtils.setup()
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local reports = collectReports(controller)

		controller.kill(victimHumanoid, killer)

		expect(#reports).toEqual(1)
		expect(reports[1].adornee).toBe(victimCharacter)
		expect(reports[1].humanoid).toBe(victimHumanoid)
		expect(reports[1].player).toBe(victim)
		expect(reports[1].killerHumanoid).toBe(killerHumanoid)
		expect(reports[1].killerPlayer).toBe(killer)

		controller:Destroy()
	end)

	it("reports an unattributed death without a killer", function()
		local controller = DeathReportTestUtils.setup()
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		local reports = collectReports(controller)

		controller.kill(victimHumanoid)

		expect(#reports).toEqual(1)
		expect(reports[1].player).toBe(victim)
		expect(reports[1].killerPlayer).toBeNil()
		expect(reports[1].killerHumanoid).toBeNil()

		controller:Destroy()
	end)
end)

describe("DeathReportService observers", function()
	it("route a report to the killer and victim player observers", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		controller.newCharacter(killer)

		local victimDeaths = collect(controller, service:ObservePlayerDeathReports(victim))
		local victimKills = collect(controller, service:ObservePlayerKillerReports(victim))
		local killerDeaths = collect(controller, service:ObservePlayerDeathReports(killer))
		local killerKills = collect(controller, service:ObservePlayerKillerReports(killer))

		controller.kill(victimHumanoid, killer)

		expect(#victimDeaths).toEqual(1)
		expect(#victimKills).toEqual(0)
		expect(#killerDeaths).toEqual(0)
		expect(#killerKills).toEqual(1)
		expect(victimDeaths[1].killerPlayer).toBe(killer)

		controller:Destroy()
	end)

	it("route a report to the humanoid and character observers", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local humanoidDeaths = collect(controller, service:ObserveHumanoidDeathReports(victimHumanoid))
		local characterDeaths = collect(controller, service:ObserveCharacterDeathReports(victimCharacter))
		local humanoidKills = collect(controller, service:ObserveHumanoidKillerReports(killerHumanoid))
		local characterKills = collect(controller, service:ObserveCharacterKillerReports(killerCharacter))

		controller.kill(victimHumanoid, killer)

		expect(#humanoidDeaths).toEqual(1)
		expect(#characterDeaths).toEqual(1)
		expect(#humanoidKills).toEqual(1)
		expect(#characterKills).toEqual(1)

		controller:Destroy()
	end)

	it("reject the wrong instance class", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local folder = Instance.new("Folder")

		expect(function()
			service:ObservePlayerDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			service:ObservePlayerKillerReports(folder :: any)
		end).toThrow()
		expect(function()
			service:ObserveHumanoidDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			service:ObserveHumanoidKillerReports(folder :: any)
		end).toThrow()
		expect(function()
			service:ObserveCharacterDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			service:ObserveCharacterKillerReports(folder :: any)
		end).toThrow()

		folder:Destroy()
		controller:Destroy()
	end)
end)

describe("DeathReportService weapon data", function()
	it("attaches the answer of the first retriever that resolves a weapon", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local _npc, npcHumanoid = controller.newNpc()
		local weapon = Instance.new("Tool")
		controller.maid:GiveTask(weapon)

		local reports = collectReports(controller)

		service:AddWeaponDataRetriever(function()
			return nil
		end)
		local removeRetriever = service:AddWeaponDataRetriever(function(humanoid: Humanoid)
			expect(humanoid).toBe(npcHumanoid)
			return DeathReportUtils.createWeaponData(weapon)
		end)

		service:ReportHumanoidDeath(npcHumanoid)
		expect(reports[1].weaponData.weaponInstance).toBe(weapon)

		removeRetriever()

		service:ReportHumanoidDeath(npcHumanoid)
		expect(reports[2].weaponData.weaponInstance).toBeNil()

		controller:Destroy()
	end)

	it("prefers explicitly passed weapon data over the retrievers", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local _npc, npcHumanoid = controller.newNpc()
		local weapon = Instance.new("Tool")
		controller.maid:GiveTask(weapon)

		local reports = collectReports(controller)

		service:AddWeaponDataRetriever(function()
			error("Should not be asked")
		end)

		service:ReportHumanoidDeath(npcHumanoid, DeathReportUtils.createWeaponData(weapon))
		expect(reports[1].weaponData.weaponInstance).toBe(weapon)

		controller:Destroy()
	end)

	it("rejects a retriever that returns invalid weapon data", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local _npc, npcHumanoid = controller.newNpc()

		service:AddWeaponDataRetriever(function()
			return { weaponInstance = 5 } :: any
		end)

		expect(function()
			service:FindWeaponData(npcHumanoid)
		end).toThrow()

		controller:Destroy()
	end)

	it("rejects a non-function retriever", function()
		local controller = DeathReportTestUtils.setup()

		expect(function()
			controller.deathReportService:AddWeaponDataRetriever(nil :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("DeathReportService.ReportDeathReport(deathReport)", function()
	it("fires NewDeathReport with the report as given", function()
		local controller = DeathReportTestUtils.setup()
		local npc = controller.newNpc()

		local reports = collectReports(controller)

		local report = DeathReportUtils.create(npc)
		controller.deathReportService:ReportDeathReport(report)

		expect(reports).toEqual({ report })
		expect(controller.deathReportService:GetLastDeathReports()).toEqual({ report })

		controller:Destroy()
	end)

	it("records the report in the bag's DeathReportDataService", function()
		local controller = DeathReportTestUtils.setup()
		local service = controller.deathReportService
		local dataService = controller.serverBag:GetService(DeathReportDataService)
		local npc = controller.newNpc()

		expect(service.NewDeathReport).toBe(dataService.NewDeathReport)

		local report = DeathReportUtils.create(npc)
		service:ReportDeathReport(report)

		expect(dataService:GetLastDeathReports()).toEqual({ report })

		controller:Destroy()
	end)

	it("rejects a value that is not a report", function()
		local controller = DeathReportTestUtils.setup()

		expect(function()
			controller.deathReportService:ReportDeathReport({} :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)
