--!strict
--[[
	Dual-realm coverage for DeathReportServiceClient. A server bag and a client bag boot in the same
	DataModel; deaths reported on the server cross dummy-mode remoting to the client the same way they
	replicate in production.

	@class DeathReportServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportTestUtils = require("DeathReportTestUtils")
local DeathReportUtils = require("DeathReportUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local controller = DeathReportTestUtils.setup({ withClient = true })

	local localPlayer = controller.newMock()
	controller.setLocalPlayer(localPlayer)
	controller.localPlayer = localPlayer

	return controller
end

local function collectClientReports(controller: any): { DeathReportUtils.DeathReport }
	local reports: { DeathReportUtils.DeathReport } = {}
	controller.maid:GiveTask(controller.deathReportServiceClient.NewDeathReport:Connect(function(report)
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

describe("DeathReportServiceClient", function()
	it("boots against the server service", function()
		local controller = setup()

		expect(controller.deathReportServiceClient).toBeDefined()
		expect(controller.deathReportServiceClient:GetLastDeathReports()).toEqual({})

		controller:Destroy()
	end)

	it("receives a death reported on the server", function()
		local controller = setup()
		local client = controller.deathReportServiceClient
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local reports = collectClientReports(controller)

		controller.kill(victimHumanoid, killer)

		expect(DeathReportTestUtils.waitFor(function()
			return #reports == 1
		end)).toBe(true)

		expect(reports[1].adornee).toBe(victimCharacter)
		expect(reports[1].humanoid).toBe(victimHumanoid)
		expect(reports[1].player).toBe(victim)
		expect(reports[1].killerHumanoid).toBe(killerHumanoid)
		expect(reports[1].killerPlayer).toBe(killer)
		expect(client:GetLastDeathReports()).toEqual({ reports[1] })

		controller:Destroy()
	end)

	it("routes replicated reports to the client observers", function()
		local controller = setup()
		local client = controller.deathReportServiceClient
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local victimDeaths = collect(controller, client:ObservePlayerDeathReports(victim))
		local killerKills = collect(controller, client:ObservePlayerKillerReports(killer))
		local humanoidDeaths = collect(controller, client:ObserveHumanoidDeathReports(victimHumanoid))
		local characterDeaths = collect(controller, client:ObserveCharacterDeathReports(victimCharacter))
		local humanoidKills = collect(controller, client:ObserveHumanoidKillerReports(killerHumanoid))
		local characterKills = collect(controller, client:ObserveCharacterKillerReports(killerCharacter))
		local victimKills = collect(controller, client:ObservePlayerKillerReports(victim))

		controller.kill(victimHumanoid, killer)

		expect(DeathReportTestUtils.waitFor(function()
			return #victimDeaths == 1
				and #killerKills == 1
				and #humanoidDeaths == 1
				and #characterDeaths == 1
				and #humanoidKills == 1
				and #characterKills == 1
		end)).toBe(true)
		expect(victimKills).toEqual({})

		controller:Destroy()
	end)

	it("keeps only the most recent reports", function()
		local controller = setup()
		local client = controller.deathReportServiceClient

		local reports = collectClientReports(controller)

		local npcs = {}
		for index = 1, 7 do
			local npc = controller.newNpc(string.format("Npc_%d", index))
			table.insert(npcs, npc)
			controller.deathReportService:ReportDeathReport(DeathReportUtils.create(npc))
		end

		expect(DeathReportTestUtils.waitFor(function()
			return #reports == 7
		end)).toBe(true)

		local lastReports = client:GetLastDeathReports()
		expect(#lastReports).toEqual(5)
		expect(lastReports[1].adornee).toBe(npcs[3])
		expect(lastReports[5].adornee).toBe(npcs[7])

		controller:Destroy()
	end)

	it("rejects the wrong instance class for observers", function()
		local controller = setup()
		local client = controller.deathReportServiceClient
		local folder = Instance.new("Folder")

		expect(function()
			client:ObservePlayerDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			client:ObservePlayerKillerReports(folder :: any)
		end).toThrow()
		expect(function()
			client:ObserveHumanoidDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			client:ObserveCharacterDeathReports(folder :: any)
		end).toThrow()

		folder:Destroy()
		controller:Destroy()
	end)
end)
