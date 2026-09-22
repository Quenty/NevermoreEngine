--!strict
--[[
	@class DeathReportProcessor.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local DeathReportProcessor = require("DeathReportProcessor")
local DeathReportTestUtils = require("DeathReportTestUtils")
local DeathReportUtils = require("DeathReportUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID_BASE = 55400000

local specCounter = 0

local function setup(): any
	specCounter += 1
	local suffix = specCounter

	local maid = Maid.new()

	local processor = maid:Add(DeathReportProcessor.new())

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

	-- Subscribes and returns the list every emission is appended to
	local function collect(observable: any): { any }
		local emissions = {}
		maid:GiveTask(observable:Subscribe(function(value)
			table.insert(emissions, value)
		end))
		return emissions
	end

	local controller = {
		processor = processor,
		newMock = newMock,
		newCharacter = newCharacter,
		collect = collect,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("DeathReportProcessor.HandleDeathReport(deathReport)", function()
	it("routes a report to every observer of the subjects involved", function()
		local controller = setup()
		local processor = controller.processor
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local playerDeaths = controller.collect(processor:ObservePlayerDeathReports(victim))
		local humanoidDeaths = controller.collect(processor:ObserveHumanoidDeathReports(victimHumanoid))
		local characterDeaths = controller.collect(processor:ObserveCharacterDeathReports(victimCharacter))
		local playerKills = controller.collect(processor:ObservePlayerKillerReports(killer))
		local humanoidKills = controller.collect(processor:ObserveHumanoidKillerReports(killerHumanoid))
		local characterKills = controller.collect(processor:ObserveCharacterKillerReports(killerCharacter))

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)
		processor:HandleDeathReport(report)

		expect(playerDeaths).toEqual({ report })
		expect(humanoidDeaths).toEqual({ report })
		expect(characterDeaths).toEqual({ report })
		expect(playerKills).toEqual({ report })
		expect(humanoidKills).toEqual({ report })
		expect(characterKills).toEqual({ report })

		controller:Destroy()
	end)

	it("does not notify observers of uninvolved subjects", function()
		local controller = setup()
		local processor = controller.processor
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)
		local bystander = controller.newMock()
		local bystanderCharacter, bystanderHumanoid = controller.newCharacter(bystander)

		local victimKills = controller.collect(processor:ObservePlayerKillerReports(victim))
		local killerDeaths = controller.collect(processor:ObservePlayerDeathReports(killer))
		local bystanderDeaths = controller.collect(processor:ObservePlayerDeathReports(bystander))
		local bystanderKills = controller.collect(processor:ObservePlayerKillerReports(bystander))
		local bystanderHumanoidDeaths = controller.collect(processor:ObserveHumanoidDeathReports(bystanderHumanoid))
		local bystanderCharacterKills = controller.collect(processor:ObserveCharacterKillerReports(bystanderCharacter))

		processor:HandleDeathReport(DeathReportUtils.create(victimCharacter, killerHumanoid))

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
		local processor = controller.processor
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)

		local playerDeaths = controller.collect(processor:ObservePlayerDeathReports(victim))

		local report = DeathReportUtils.create(victimCharacter)
		processor:HandleDeathReport(report)

		expect(playerDeaths).toEqual({ report })

		controller:Destroy()
	end)

	it("rejects a value that is not a report", function()
		local controller = setup()

		expect(function()
			controller.processor:HandleDeathReport({} :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("DeathReportProcessor player observers", function()
	it("complete when the mock player is removed", function()
		local controller = setup()
		local processor = controller.processor
		local mock = controller.newMock()

		local completed = { deaths = false, kills = false }
		local deathSub = processor:ObservePlayerDeathReports(mock):Subscribe(nil, nil, function()
			completed.deaths = true
		end)
		local killSub = processor:ObservePlayerKillerReports(mock):Subscribe(nil, nil, function()
			completed.kills = true
		end)

		mock:Destroy()

		expect(DeathReportTestUtils.waitFor(function()
			return completed.deaths and completed.kills
		end)).toBe(true)

		deathSub:Destroy()
		killSub:Destroy()
		controller:Destroy()
	end)

	it("reject a non-player subject", function()
		local controller = setup()
		local folder = Instance.new("Folder")

		expect(function()
			controller.processor:ObservePlayerDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			controller.processor:ObservePlayerKillerReports(folder :: any)
		end).toThrow()

		folder:Destroy()
		controller:Destroy()
	end)
end)

describe("DeathReportProcessor humanoid and character observers", function()
	it("reject the wrong instance class", function()
		local controller = setup()
		local folder = Instance.new("Folder")

		expect(function()
			controller.processor:ObserveHumanoidDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			controller.processor:ObserveHumanoidKillerReports(folder :: any)
		end).toThrow()
		expect(function()
			controller.processor:ObserveCharacterDeathReports(folder :: any)
		end).toThrow()
		expect(function()
			controller.processor:ObserveCharacterKillerReports(folder :: any)
		end).toThrow()

		folder:Destroy()
		controller:Destroy()
	end)
end)
