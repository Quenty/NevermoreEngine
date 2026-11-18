--!strict
--[[
	@class RxTeamUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Teams = game:GetService("Teams")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local RxBrioTestUtils = require("RxBrioTestUtils")
local RxTeamUtils = require("RxTeamUtils")
local RxTestUtils = require("RxTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local RED = BrickColor.new("Bright red")
local BLUE = BrickColor.new("Bright blue")

type Controller = {
	newTeam: (color: BrickColor?) -> Team,
	maid: Maid.Maid,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newTeam = function(color)
			local team = Instance.new("Team")
			team.Name = "RxTeamUtilsSpecTeam"
			team.TeamColor = color or RED
			team.Parent = Teams
			maid:GiveTask(team)
			return team
		end,

		maid = maid,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RxTeamUtils.observeTeamsBrio", function()
	it("emits teams that already exist", function()
		local controller = setup()
		local teamA = controller.newTeam()
		local teamB = controller.newTeam()

		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsBrio())

		expect(aliveTeams).toContain(teamA)
		expect(aliveTeams).toContain(teamB)

		controller:Destroy()
	end)

	it("emits teams added later", function()
		local controller = setup()
		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsBrio())

		local team = controller.newTeam()

		expect(aliveTeams).toContain(team)

		controller:Destroy()
	end)

	it("kills the brio when the team is removed", function()
		local controller = setup()
		local team = controller.newTeam()
		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsBrio())
		expect(aliveTeams).toContain(team)

		team.Parent = nil

		expect(aliveTeams).never.toContain(team)

		controller:Destroy()
	end)

	it("ignores children of Teams that are not teams", function()
		local controller = setup()
		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsBrio())

		local folder = Instance.new("Folder")
		folder.Parent = Teams
		local team = controller.newTeam()

		expect(aliveTeams).toContain(team)
		expect(aliveTeams).never.toContain(folder)

		folder:Destroy()
		controller:Destroy()
	end)

	it("kills every brio on unsubscribe", function()
		local controller = setup()
		local teamA = controller.newTeam()
		local teamB = controller.newTeam()

		local subscriptionMaid = Maid.new()
		local aliveTeams = RxBrioTestUtils.collectAliveList(subscriptionMaid, RxTeamUtils.observeTeamsBrio())
		expect(aliveTeams).toContain(teamA)
		expect(aliveTeams).toContain(teamB)

		subscriptionMaid:Destroy()

		expect(aliveTeams).toEqual({})

		controller:Destroy()
	end)
end)

describe("RxTeamUtils.observeTeamsForColorBrio", function()
	it("rejects a non-BrickColor", function()
		expect(function()
			RxTeamUtils.observeTeamsForColorBrio(Color3.new() :: any)
		end).toThrow("Bad teamColor")
	end)

	it("emits only teams of the given color", function()
		local controller = setup()
		local red = controller.newTeam(RED)
		local blue = controller.newTeam(BLUE)

		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsForColorBrio(RED))

		expect(aliveTeams).toContain(red)
		expect(aliveTeams).never.toContain(blue)

		controller:Destroy()
	end)

	it("emits a team once its color changes to match", function()
		local controller = setup()
		local team = controller.newTeam(BLUE)
		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsForColorBrio(RED))

		expect(aliveTeams).never.toContain(team)

		team.TeamColor = RED

		expect(aliveTeams).toContain(team)

		controller:Destroy()
	end)

	it("kills the brio once the color no longer matches", function()
		local controller = setup()
		local team = controller.newTeam(RED)
		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsForColorBrio(RED))
		expect(aliveTeams).toContain(team)

		team.TeamColor = BLUE

		expect(aliveTeams).never.toContain(team)

		controller:Destroy()
	end)

	it("kills the brio when the team is removed", function()
		local controller = setup()
		local team = controller.newTeam(RED)
		local aliveTeams = RxBrioTestUtils.collectAliveList(controller.maid, RxTeamUtils.observeTeamsForColorBrio(RED))
		expect(aliveTeams).toContain(team)

		team.Parent = nil

		expect(aliveTeams).never.toContain(team)

		controller:Destroy()
	end)
end)

describe("RxTeamUtils.observePlayersForTeamBrio", function()
	it("rejects a non-team", function()
		local controller = setup()

		expect(function()
			RxTeamUtils.observePlayersForTeamBrio(Instance.new("Folder") :: any)
		end).toThrow("Bad team")

		controller:Destroy()
	end)

	it("emits nothing for a team with no players", function()
		local controller = setup()
		local team = controller.newTeam()

		local brios = RxTestUtils.collectList(controller.maid, RxTeamUtils.observePlayersForTeamBrio(team))

		expect(#brios).toBe(0)

		controller:Destroy()
	end)
end)

describe("RxTeamUtils.observePlayersForTeamColorBrio", function()
	it("rejects a non-BrickColor", function()
		expect(function()
			RxTeamUtils.observePlayersForTeamColorBrio("Bright red" :: any)
		end).toThrow("Bad teamColor")
	end)

	it("emits nothing when the matching team has no players", function()
		local controller = setup()
		controller.newTeam(RED)

		local brios = RxTestUtils.collectList(controller.maid, RxTeamUtils.observePlayersForTeamColorBrio(RED))

		expect(#brios).toBe(0)

		controller:Destroy()
	end)
end)

describe("RxTeamUtils.observeEnemyTeamColorPlayersBrio", function()
	it("rejects a non-BrickColor", function()
		expect(function()
			RxTeamUtils.observeEnemyTeamColorPlayersBrio(nil :: any)
		end).toThrow("Bad teamColor")
	end)
end)
