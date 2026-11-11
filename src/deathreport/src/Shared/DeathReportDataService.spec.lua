--!strict
--[[
	@class DeathReportDataService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local DeathReportDataService = require("DeathReportDataService")
local DeathReportTestUtils = require("DeathReportTestUtils")
local DeathReportUtils = require("DeathReportUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local TeamKillTrackerUtils = require("TeamKillTrackerUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID_BASE = 55500000

local specCounter = 0

local function setup(): any
	specCounter += 1
	local suffix = specCounter

	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local dataService = serviceBag:GetService(DeathReportDataService)
	serviceBag:Init()
	serviceBag:Start()

	local mockCounter = 0
	local function newMock(): Player
		mockCounter += 1

		local mock = PlayerMock.new({ UserId = USER_ID_BASE + suffix * 100 + mockCounter })
		mock.Parent = Players
		maid:GiveTask(mock)

		return mock
	end

	local function newCharacter(mock: Player): (Model, Humanoid)
		local character = PlayerMock.loadMinimalCharacterAsync(mock)
		return character, assert(character:FindFirstChildWhichIsA("Humanoid"), "No humanoid")
	end

	local function newNpc(name: string?): (Model, Humanoid)
		local character = Instance.new("Model")
		character.Name = name or "Npc"
		maid:GiveTask(character)

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		return character, humanoid
	end

	local function collect(observable: any): { any }
		local emissions = {}
		maid:GiveTask(observable:Subscribe(function(value)
			table.insert(emissions, value)
		end))
		return emissions
	end

	local controller = {
		maid = maid,
		serviceBag = serviceBag,
		dataService = dataService,
		newMock = newMock,
		newCharacter = newCharacter,
		newNpc = newNpc,
		collect = collect,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("DeathReportDataService.HandleDeathReport(deathReport)", function()
	it("fires NewDeathReport and routes the report to every observer of the subjects involved", function()
		local controller = setup()
		local dataService = controller.dataService
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local reports = {}
		controller.maid:GiveTask(dataService.NewDeathReport:Connect(function(report)
			table.insert(reports, report)
		end))
		local victimDeaths = controller.collect(dataService:ObservePlayerDeathReports(victim))
		local victimKills = controller.collect(dataService:ObservePlayerKillerReports(victim))
		local killerKills = controller.collect(dataService:ObservePlayerKillerReports(killer))
		local humanoidDeaths = controller.collect(dataService:ObserveHumanoidDeathReports(victimHumanoid))
		local characterDeaths = controller.collect(dataService:ObserveCharacterDeathReports(victimCharacter))
		local humanoidKills = controller.collect(dataService:ObserveHumanoidKillerReports(killerHumanoid))
		local characterKills = controller.collect(dataService:ObserveCharacterKillerReports(killerCharacter))

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)
		dataService:HandleDeathReport(report)

		expect(reports).toEqual({ report })
		expect(victimDeaths).toEqual({ report })
		expect(victimKills).toEqual({})
		expect(killerKills).toEqual({ report })
		expect(humanoidDeaths).toEqual({ report })
		expect(characterDeaths).toEqual({ report })
		expect(humanoidKills).toEqual({ report })
		expect(characterKills).toEqual({ report })

		controller:Destroy()
	end)

	it("does not notify observers of uninvolved subjects", function()
		local controller = setup()
		local dataService = controller.dataService
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)
		local bystander = controller.newMock()
		local bystanderCharacter, bystanderHumanoid = controller.newCharacter(bystander)

		local victimKills = controller.collect(dataService:ObservePlayerKillerReports(victim))
		local killerDeaths = controller.collect(dataService:ObservePlayerDeathReports(killer))
		local bystanderDeaths = controller.collect(dataService:ObservePlayerDeathReports(bystander))
		local bystanderKills = controller.collect(dataService:ObservePlayerKillerReports(bystander))
		local bystanderHumanoidDeaths = controller.collect(dataService:ObserveHumanoidDeathReports(bystanderHumanoid))
		local bystanderCharacterKills =
			controller.collect(dataService:ObserveCharacterKillerReports(bystanderCharacter))

		dataService:HandleDeathReport(DeathReportUtils.create(victimCharacter, killerHumanoid))

		expect(victimKills).toEqual({})
		expect(killerDeaths).toEqual({})
		expect(bystanderDeaths).toEqual({})
		expect(bystanderKills).toEqual({})
		expect(bystanderHumanoidDeaths).toEqual({})
		expect(bystanderCharacterKills).toEqual({})

		controller:Destroy()
	end)

	it("routes an unattributed death only to the victim observers", function()
		local controller = setup()
		local dataService = controller.dataService
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)

		local playerDeaths = controller.collect(dataService:ObservePlayerDeathReports(victim))

		local report = DeathReportUtils.create(victimCharacter)
		dataService:HandleDeathReport(report)

		expect(playerDeaths).toEqual({ report })

		controller:Destroy()
	end)

	it("rejects a value that is not a report", function()
		local controller = setup()

		expect(function()
			controller.dataService:HandleDeathReport({} :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("DeathReportDataService.GetLastDeathReports()", function()
	it("starts empty", function()
		local controller = setup()

		expect(controller.dataService:GetLastDeathReports()).toEqual({})

		controller:Destroy()
	end)

	it("keeps only the most recent reports, oldest first", function()
		local controller = setup()
		local dataService = controller.dataService

		local npcs = {}
		for index = 1, 7 do
			local npc = controller.newNpc(string.format("Npc_%d", index))
			table.insert(npcs, npc)
			dataService:HandleDeathReport(DeathReportUtils.create(npc))
		end

		local lastReports = dataService:GetLastDeathReports()
		expect(#lastReports).toEqual(5)
		expect(lastReports[1].adornee).toBe(npcs[3])
		expect(lastReports[5].adornee).toBe(npcs[7])

		controller:Destroy()
	end)
end)

describe("DeathReportDataService observers", function()
	it("complete the player observers when the mock player is removed", function()
		local controller = setup()
		local dataService = controller.dataService
		local mock = controller.newMock()

		local completed = { deaths = false, kills = false }
		controller.maid:GiveTask(dataService:ObservePlayerDeathReports(mock):Subscribe(nil, nil, function()
			completed.deaths = true
		end))
		controller.maid:GiveTask(dataService:ObservePlayerKillerReports(mock):Subscribe(nil, nil, function()
			completed.kills = true
		end))

		mock:Destroy()

		expect(DeathReportTestUtils.waitFor(function()
			return completed.deaths and completed.kills
		end)).toBe(true)

		controller:Destroy()
	end)

	it("reject the wrong instance class", function()
		local controller = setup()
		local dataService = controller.dataService
		local folder = Instance.new("Folder")

		expect(function()
			dataService:ObservePlayerDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			dataService:ObservePlayerKillerReports(folder :: any)
		end).toThrow()
		expect(function()
			dataService:ObserveHumanoidDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			dataService:ObserveHumanoidKillerReports(folder :: any)
		end).toThrow()
		expect(function()
			dataService:ObserveCharacterDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			dataService:ObserveCharacterKillerReports(folder :: any)
		end).toThrow()

		folder:Destroy()
		controller:Destroy()
	end)
end)

-- Emissions may be nil, so each one is boxed
local function collectBoxed(controller: any, observable: any): { { value: any } }
	local emissions = {}
	controller.maid:GiveTask(observable:Subscribe(function(value)
		table.insert(emissions, { value = value })
	end))
	return emissions
end

describe("DeathReportDataService tracker observers", function()
	it("emit nil without a tracker and the count once one is bound", function()
		local controller = DeathReportTestUtils.setup()
		local dataService = controller.serverBag:GetService(DeathReportDataService)
		local binder = controller.playerKillTrackerBinder
		local mock = controller.newMock()

		DeathReportTestUtils.awaitBound(binder, mock)
		binder:Unbind(mock)
		DeathReportTestUtils.awaitUnbound(binder, mock)

		local kills = collectBoxed(controller, dataService:ObservePlayerKillCount(mock))
		expect(#kills).toEqual(1)
		expect(kills[1].value).toBeNil()

		binder:Bind(mock)
		DeathReportTestUtils.awaitBound(binder, mock)

		expect(kills[#kills].value).toEqual(0)

		binder:Unbind(mock)
		DeathReportTestUtils.awaitUnbound(binder, mock)

		expect(kills[#kills].value).toBeNil()

		controller:Destroy()
	end)

	it("observe player kills and deaths in the server realm", function()
		local controller = DeathReportTestUtils.setup()
		local dataService = controller.serverBag:GetService(DeathReportDataService)
		local killer = controller.newMock()
		controller.newCharacter(killer)
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		DeathReportTestUtils.awaitBound(controller.playerKillTrackerBinder, killer)
		DeathReportTestUtils.awaitBound(controller.playerDeathTrackerBinder, victim)

		local kills = collectBoxed(controller, dataService:ObservePlayerKillCount(killer))
		local deaths = collectBoxed(controller, dataService:ObservePlayerDeathCount(victim))
		expect(kills[#kills].value).toEqual(0)
		expect(deaths[#deaths].value).toEqual(0)

		controller.kill(victimHumanoid, killer)

		expect(kills[#kills].value).toEqual(1)
		expect(deaths[#deaths].value).toEqual(1)

		controller:Destroy()
	end)

	it("observe team kills in the server realm", function()
		local controller = DeathReportTestUtils.setup()
		local dataService = controller.serverBag:GetService(DeathReportDataService)
		local team = controller.newTeam()
		local score = TeamKillTrackerUtils.create(controller.teamKillTrackerBinder)
		score.Parent = team
		DeathReportTestUtils.awaitBound(controller.teamKillTrackerBinder, score)

		local killer = controller.newMock()
		controller.setTeam(killer, team)
		controller.newCharacter(killer)
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		local kills = collectBoxed(controller, dataService:ObserveTeamKillCount(team))
		expect(kills[#kills].value).toEqual(0)

		controller.kill(victimHumanoid, killer)

		expect(kills[#kills].value).toEqual(1)

		controller:Destroy()
	end)

	it("observe the replicated trackers in the client realm", function()
		local controller = DeathReportTestUtils.setup({ withClient = true })
		local dataService = controller.clientBag:GetService(DeathReportDataService)
		local killer = controller.newMock()
		controller.setLocalPlayer(killer)
		controller.newCharacter(killer)
		local victim = controller.newMock()
		local _victimCharacter, victimHumanoid = controller.newCharacter(victim)

		DeathReportTestUtils.awaitBound(controller.playerKillTrackerClientBinder, killer)

		local kills = collectBoxed(controller, dataService:ObservePlayerKillCount(killer))

		controller.kill(victimHumanoid, killer)

		expect(DeathReportTestUtils.waitFor(function()
			return kills[#kills].value == 1
		end)).toBe(true)

		controller:Destroy()
	end)

	it("reject the wrong instance class", function()
		local controller = setup()
		local folder = Instance.new("Folder")

		expect(function()
			controller.dataService:ObservePlayerKillCount(folder :: any)
		end).toThrow()
		expect(function()
			controller.dataService:ObservePlayerDeathCount(folder :: any)
		end).toThrow()
		expect(function()
			controller.dataService:ObserveTeamKillCount(folder :: any)
		end).toThrow()

		folder:Destroy()
		controller:Destroy()
	end)
end)
