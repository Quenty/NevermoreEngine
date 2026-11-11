--!strict
--[[
	@class TeamUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Teams = game:GetService("Teams")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local TeamUtils = require("TeamUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newTeam: () -> Team,
	newPlayer: (team: Team?) -> Player,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local controller: Controller = {
		newTeam = function()
			local team = Instance.new("Team")
			team.Name = "TeamUtilsSpecTeam"
			team.Parent = Teams
			maid:GiveTask(team)
			return team
		end,

		newPlayer = function(team)
			local player: Player = maid:Add(PlayerMock.new())
			if team then
				PlayerMock.write(player, "Team", team)
				PlayerMock.write(player, "Neutral", false)
			end
			return player
		end,

		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TeamUtils.getTeam", function()
	it("returns nil for a player that has never been assigned a team", function()
		local controller = setup()
		local player = controller.newPlayer()

		expect(TeamUtils.getTeam(player)).toBeNil()

		controller:Destroy()
	end)

	it("returns the assigned team", function()
		local controller = setup()
		local team = controller.newTeam()
		local player = controller.newPlayer(team)

		expect(TeamUtils.getTeam(player)).toBe(team)

		controller:Destroy()
	end)

	it("returns nil when a player with a team is neutral", function()
		local controller = setup()
		local team = controller.newTeam()
		local player = controller.newPlayer(team)

		PlayerMock.write(player, "Neutral", true)

		expect(TeamUtils.getTeam(player)).toBeNil()

		controller:Destroy()
	end)

	it("follows a team change", function()
		local controller = setup()
		local first = controller.newTeam()
		local second = controller.newTeam()
		local player = controller.newPlayer(first)

		PlayerMock.write(player, "Team", second)

		expect(TeamUtils.getTeam(player)).toBe(second)

		controller:Destroy()
	end)
end)

describe("TeamUtils.areTeamMates", function()
	it("is true for two players on the same team", function()
		local controller = setup()
		local team = controller.newTeam()
		local playerA = controller.newPlayer(team)
		local playerB = controller.newPlayer(team)

		expect(TeamUtils.areTeamMates(playerA, playerB)).toBe(true)

		controller:Destroy()
	end)

	it("is true for a player and themselves", function()
		local controller = setup()
		local team = controller.newTeam()
		local player = controller.newPlayer(team)

		expect(TeamUtils.areTeamMates(player, player)).toBe(true)

		controller:Destroy()
	end)

	it("is false for players on different teams", function()
		local controller = setup()
		local playerA = controller.newPlayer(controller.newTeam())
		local playerB = controller.newPlayer(controller.newTeam())

		expect(TeamUtils.areTeamMates(playerA, playerB)).toBe(false)

		controller:Destroy()
	end)

	it("is false when one player is neutral", function()
		local controller = setup()
		local team = controller.newTeam()
		local playerA = controller.newPlayer(team)
		local playerB = controller.newPlayer(team)

		PlayerMock.write(playerB, "Neutral", true)

		expect(TeamUtils.areTeamMates(playerA, playerB)).toBe(false)
		expect(TeamUtils.areTeamMates(playerB, playerA)).toBe(false)

		controller:Destroy()
	end)

	it("is false when both players are neutral", function()
		local controller = setup()
		local playerA = controller.newPlayer()
		local playerB = controller.newPlayer()

		expect(TeamUtils.areTeamMates(playerA, playerB)).toBe(false)

		controller:Destroy()
	end)
end)
