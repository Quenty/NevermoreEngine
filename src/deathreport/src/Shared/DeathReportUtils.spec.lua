--!strict
--[[
	@class DeathReportUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local DeathReportUtils = require("DeathReportUtils")
local HumanoidKillerUtils = require("HumanoidKillerUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local USER_ID_BASE = 55300000

local specCounter = 0

local function setup(): any
	specCounter += 1
	local suffix = specCounter

	local maid = Maid.new()

	local container = Instance.new("Folder")
	container.Name = string.format("DeathReportUtilsSpecContainer_%d", suffix)
	container.Parent = Workspace
	maid:GiveTask(container)

	local mockCounter = 0
	local function newMock(overrides: { [string]: any }?): Player
		mockCounter += 1

		local seed: { [string]: any } = { UserId = USER_ID_BASE + suffix * 100 + mockCounter }
		if overrides then
			for key, value in overrides do
				seed[key] = value
			end
		end

		local mock = PlayerMock.new(seed)
		mock.Parent = Players
		maid:GiveTask(mock)

		return mock
	end

	local function newCharacter(mock: Player): (Model, Humanoid)
		local character = PlayerMock.loadMinimalCharacterAsync(mock)
		return character, assert(character:FindFirstChildWhichIsA("Humanoid"), "No humanoid")
	end

	local function newNpc(name: string): (Model, Humanoid)
		local character = Instance.new("Model")
		character.Name = name

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		character.Parent = container

		return character, humanoid
	end

	local function newTeam(brickColor: BrickColor): Team
		local team = Instance.new("Team")
		team.Name = string.format("DeathReportUtilsSpecTeam_%d", suffix)
		team.TeamColor = brickColor
		team.AutoAssignable = false
		team.Parent = Teams
		maid:GiveTask(team)

		return team
	end

	local function setTeam(mock: Player, team: Team?)
		PlayerMock.write(mock, "Team", team)
		PlayerMock.write(mock, "Neutral", team == nil)
	end

	local controller = {
		newMock = newMock,
		newCharacter = newCharacter,
		newNpc = newNpc,
		newTeam = newTeam,
		setTeam = setTeam,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("DeathReportUtils.isDeathReport(deathReport)", function()
	it("should return true for a valid death report table", function()
		expect(DeathReportUtils.isDeathReport({ type = "deathReport" })).toEqual(true)
	end)

	it("should return false for nil", function()
		expect(DeathReportUtils.isDeathReport(nil)).toEqual(false)
	end)

	it("should return false for a table with wrong type", function()
		expect(DeathReportUtils.isDeathReport({ type = "other" })).toEqual(false)
	end)
end)

describe("DeathReportUtils.isWeaponData(weaponData)", function()
	it("accepts an empty table", function()
		expect(DeathReportUtils.isWeaponData({})).toEqual(true)
	end)

	it("accepts an instance weapon", function()
		local weapon = Instance.new("Tool")
		expect(DeathReportUtils.isWeaponData({ weaponInstance = weapon })).toEqual(true)
		weapon:Destroy()
	end)

	it("rejects a non-instance weapon", function()
		expect(DeathReportUtils.isWeaponData({ weaponInstance = 5 })).toEqual(false)
	end)

	it("rejects nil", function()
		expect(DeathReportUtils.isWeaponData(nil)).toEqual(false)
	end)
end)

describe("DeathReportUtils.createWeaponData(weaponInstance)", function()
	it("wraps the weapon instance", function()
		local weapon = Instance.new("Tool")
		expect(DeathReportUtils.createWeaponData(weapon)).toEqual({ weaponInstance = weapon })
		weapon:Destroy()
	end)

	it("allows no weapon", function()
		expect(DeathReportUtils.createWeaponData(nil)).toEqual({})
	end)

	it("rejects a non-instance", function()
		expect(function()
			DeathReportUtils.createWeaponData(5 :: any)
		end).toThrow()
	end)
end)

describe("DeathReportUtils.create(adornee, killerAdornee, weaponData)", function()
	it("resolves the humanoid and player of a mock character", function()
		local controller = setup()
		local mock = controller.newMock()
		local character, humanoid = controller.newCharacter(mock)

		local report = DeathReportUtils.create(character)

		expect(report.type).toEqual("deathReport")
		expect(report.adornee).toBe(character)
		expect(report.humanoid).toBe(humanoid)
		expect(report.player).toBe(mock)
		expect(report.killerAdornee).toBeNil()
		expect(report.killerHumanoid).toBeNil()
		expect(report.killerPlayer).toBeNil()
		expect(report.weaponData).toEqual({})

		controller:Destroy()
	end)

	it("accepts a humanoid as the adornee", function()
		local controller = setup()
		local _character, humanoid = controller.newNpc("Zombie")

		local report = DeathReportUtils.create(humanoid)

		expect(report.adornee).toBe(humanoid)
		expect(report.humanoid).toBe(humanoid)
		expect(report.player).toBeNil()

		controller:Destroy()
	end)

	it("resolves the killer humanoid and player", function()
		local controller = setup()
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)
		local weapon = Instance.new("Tool")

		local report =
			DeathReportUtils.create(victimCharacter, killerHumanoid, DeathReportUtils.createWeaponData(weapon))

		expect(report.player).toBe(victim)
		expect(report.killerAdornee).toBe(killerHumanoid)
		expect(report.killerHumanoid).toBe(killerHumanoid)
		expect(report.killerPlayer).toBe(killer)
		expect(report.weaponData.weaponInstance).toBe(weapon)

		weapon:Destroy()
		controller:Destroy()
	end)

	it("resolves only the killer player from a killer character", function()
		local controller = setup()
		local victimCharacter = controller.newNpc("Victim")
		local killer = controller.newMock()
		local killerCharacter = controller.newCharacter(killer)

		local report = DeathReportUtils.create(victimCharacter, killerCharacter)

		expect(report.killerAdornee).toBe(killerCharacter)
		expect(report.killerHumanoid).toBeNil()
		expect(report.killerPlayer).toBe(killer)

		controller:Destroy()
	end)

	it("rejects a non-instance adornee", function()
		expect(function()
			DeathReportUtils.create({} :: any)
		end).toThrow()
	end)
end)

describe("DeathReportUtils.fromDeceasedHumanoid(humanoid, weaponData)", function()
	it("reads the killer from the creator tag", function()
		local controller = setup()
		local victim = controller.newMock()
		local victimCharacter, victimHumanoid = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)

		HumanoidKillerUtils.tagKiller(victimHumanoid, killer)

		local report = DeathReportUtils.fromDeceasedHumanoid(victimHumanoid)

		expect(report.adornee).toBe(victimCharacter)
		expect(report.player).toBe(victim)
		expect(report.killerHumanoid).toBe(killerHumanoid)
		expect(report.killerPlayer).toBe(killer)

		controller:Destroy()
	end)

	it("reports no killer without a creator tag", function()
		local controller = setup()
		local _character, humanoid = controller.newNpc("Zombie")

		local report = DeathReportUtils.fromDeceasedHumanoid(humanoid)

		expect(report.humanoid).toBe(humanoid)
		expect(report.killerPlayer).toBeNil()
		expect(report.killerHumanoid).toBeNil()

		controller:Destroy()
	end)

	it("rejects a humanoid without a character", function()
		local humanoid = Instance.new("Humanoid")

		expect(function()
			DeathReportUtils.fromDeceasedHumanoid(humanoid)
		end).toThrow()

		humanoid:Destroy()
	end)

	it("rejects invalid weapon data", function()
		local controller = setup()
		local _character, humanoid = controller.newNpc("Zombie")

		expect(function()
			DeathReportUtils.fromDeceasedHumanoid(humanoid, { weaponInstance = 5 } :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("DeathReportUtils.getDeadDisplayName(deathReport)", function()
	it("uses the display name of a mock player", function()
		local controller = setup()
		local mock = controller.newMock({ DisplayName = "Victim" })
		local character = controller.newCharacter(mock)

		expect(DeathReportUtils.getDeadDisplayName(DeathReportUtils.create(character))).toEqual("Victim")

		controller:Destroy()
	end)

	it("uses the character name of a non-player humanoid", function()
		local controller = setup()
		local character = controller.newNpc("Zombie")

		expect(DeathReportUtils.getDeadDisplayName(DeathReportUtils.create(character))).toEqual("Zombie")

		controller:Destroy()
	end)

	it("returns nil for an adornee with no humanoid", function()
		local part = Instance.new("Part")

		expect(DeathReportUtils.getDeadDisplayName(DeathReportUtils.create(part))).toBeNil()

		part:Destroy()
	end)
end)

describe("DeathReportUtils.getKillerDisplayName(deathReport)", function()
	it("uses the display name of a mock killer", function()
		local controller = setup()
		local victimCharacter = controller.newNpc("Victim")
		local killer = controller.newMock({ DisplayName = "Killer" })
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)

		expect(DeathReportUtils.getKillerDisplayName(report)).toEqual("Killer")

		controller:Destroy()
	end)

	it("uses the character name of a non-player killer", function()
		local controller = setup()
		local victimCharacter = controller.newNpc("Victim")
		local _killerCharacter, killerHumanoid = controller.newNpc("Zombie")

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)

		expect(DeathReportUtils.getKillerDisplayName(report)).toEqual("Zombie")

		controller:Destroy()
	end)

	it("returns nil without a killer", function()
		local controller = setup()
		local victimCharacter = controller.newNpc("Victim")

		expect(DeathReportUtils.getKillerDisplayName(DeathReportUtils.create(victimCharacter))).toBeNil()

		controller:Destroy()
	end)
end)

describe("DeathReportUtils.involvesPlayer(deathReport, player)", function()
	it("is true for the victim and the killer and false for a bystander", function()
		local controller = setup()
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)
		local bystander = controller.newMock()

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)

		expect(DeathReportUtils.involvesPlayer(report, victim)).toEqual(true)
		expect(DeathReportUtils.involvesPlayer(report, killer)).toEqual(true)
		expect(DeathReportUtils.involvesPlayer(report, bystander)).toEqual(false)

		controller:Destroy()
	end)

	it("rejects a non-player", function()
		local controller = setup()
		local victimCharacter = controller.newNpc("Victim")
		local report = DeathReportUtils.create(victimCharacter)

		expect(function()
			DeathReportUtils.involvesPlayer(report, victimCharacter :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("DeathReportUtils.getDeadColor(deathReport) and getKillerColor(deathReport)", function()
	it("use the team colors of the players involved", function()
		local controller = setup()
		local redTeam = controller.newTeam(BrickColor.new("Bright red"))
		local blueTeam = controller.newTeam(BrickColor.new("Bright blue"))

		local victim = controller.newMock()
		controller.setTeam(victim, blueTeam)
		local victimCharacter = controller.newCharacter(victim)

		local killer = controller.newMock()
		controller.setTeam(killer, redTeam)
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)

		expect(DeathReportUtils.getDeadColor(report)).toEqual(BrickColor.new("Bright blue").Color)
		expect(DeathReportUtils.getKillerColor(report)).toEqual(BrickColor.new("Bright red").Color)

		controller:Destroy()
	end)

	it("return nil for players without a team", function()
		local controller = setup()
		local victim = controller.newMock()
		local victimCharacter = controller.newCharacter(victim)
		local killer = controller.newMock()
		local _killerCharacter, killerHumanoid = controller.newCharacter(killer)

		local report = DeathReportUtils.create(victimCharacter, killerHumanoid)

		expect(DeathReportUtils.getDeadColor(report)).toBeNil()
		expect(DeathReportUtils.getKillerColor(report)).toBeNil()

		controller:Destroy()
	end)

	it("return nil without players", function()
		local controller = setup()
		local victimCharacter = controller.newNpc("Victim")

		local report = DeathReportUtils.create(victimCharacter)

		expect(DeathReportUtils.getDeadColor(report)).toBeNil()
		expect(DeathReportUtils.getKillerColor(report)).toBeNil()

		controller:Destroy()
	end)
end)

describe("DeathReportUtils.getDefaultColor()", function()
	it("should return a Color3", function()
		local color = DeathReportUtils.getDefaultColor()
		expect(typeof(color)).toEqual("Color3")
	end)
end)
