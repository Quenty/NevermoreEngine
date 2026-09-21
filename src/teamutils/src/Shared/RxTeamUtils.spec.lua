--!strict
--[[
	@class RxTeamUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Teams = game:GetService("Teams")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local RxTeamUtils = require("RxTeamUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local RED = BrickColor.new("Bright red")
local BLUE = BrickColor.new("Bright blue")

type Controller = {
	newTeam: (color: BrickColor?) -> Team,
	record: (observable: Observable.Observable<any>) -> { any },
	live: (brios: { any }) -> { any },
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local created: { [Instance]: true } = {}

	local controller: Controller = {
		newTeam = function(color)
			local team = Instance.new("Team")
			team.Name = "RxTeamUtilsSpecTeam"
			team.TeamColor = color or RED
			team.Parent = Teams
			maid:GiveTask(team)
			created[team] = true
			return team
		end,

		record = function(observable)
			local brios = {}
			maid:GiveTask(observable:Subscribe(function(brio)
				table.insert(brios, brio)
			end))
			return brios
		end,

		-- The test place is shared, so only values this controller created count.
		live = function(brios)
			local values = {}
			for _, brio in brios do
				if not brio:IsDead() and created[brio:GetValue()] then
					table.insert(values, brio:GetValue())
				end
			end
			return values
		end,

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

		local brios = controller.record(RxTeamUtils.observeTeamsBrio())

		local live = controller.live(brios)
		expect(#live).toBe(2)
		expect(live).toContain(teamA)
		expect(live).toContain(teamB)

		controller:Destroy()
	end)

	it("emits teams added later", function()
		local controller = setup()
		local brios = controller.record(RxTeamUtils.observeTeamsBrio())

		local team = controller.newTeam()

		local live = controller.live(brios)
		expect(#live).toBe(1)
		expect(live[1]).toBe(team)

		controller:Destroy()
	end)

	it("kills the brio when the team is removed", function()
		local controller = setup()
		local team = controller.newTeam()
		local brios = controller.record(RxTeamUtils.observeTeamsBrio())

		team.Parent = nil

		expect(#controller.live(brios)).toBe(0)

		controller:Destroy()
	end)

	it("ignores children of Teams that are not teams", function()
		local controller = setup()
		local brios = controller.record(RxTeamUtils.observeTeamsBrio())

		local folder = Instance.new("Folder")
		folder.Parent = Teams
		local before = #brios
		controller.newTeam()

		expect(#brios).toBe(before + 1)

		folder:Destroy()
		controller:Destroy()
	end)

	it("kills every brio on unsubscribe", function()
		local controller = setup()
		controller.newTeam()
		controller.newTeam()

		local brios = {}
		local subscription = RxTeamUtils.observeTeamsBrio():Subscribe(function(brio)
			table.insert(brios, brio)
		end)
		subscription:Destroy()

		expect(#controller.live(brios)).toBe(0)

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
		controller.newTeam(BLUE)

		local brios = controller.record(RxTeamUtils.observeTeamsForColorBrio(RED))

		local live = controller.live(brios)
		expect(#live).toBe(1)
		expect(live[1]).toBe(red)

		controller:Destroy()
	end)

	it("emits a team once its color changes to match", function()
		local controller = setup()
		local team = controller.newTeam(BLUE)
		local brios = controller.record(RxTeamUtils.observeTeamsForColorBrio(RED))

		expect(#controller.live(brios)).toBe(0)

		team.TeamColor = RED

		local live = controller.live(brios)
		expect(#live).toBe(1)
		expect(live[1]).toBe(team)

		controller:Destroy()
	end)

	it("kills the brio once the color no longer matches", function()
		local controller = setup()
		local team = controller.newTeam(RED)
		local brios = controller.record(RxTeamUtils.observeTeamsForColorBrio(RED))

		team.TeamColor = BLUE

		expect(#controller.live(brios)).toBe(0)

		controller:Destroy()
	end)

	it("kills the brio when the team is removed", function()
		local controller = setup()
		local team = controller.newTeam(RED)
		local brios = controller.record(RxTeamUtils.observeTeamsForColorBrio(RED))

		team.Parent = nil

		expect(#controller.live(brios)).toBe(0)

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

		local brios = controller.record(RxTeamUtils.observePlayersForTeamBrio(team))

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

		local brios = controller.record(RxTeamUtils.observePlayersForTeamColorBrio(RED))

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
