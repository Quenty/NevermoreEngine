--!strict
--[[
	@class playtest-players.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")
local PlaytestPlayersAction = require("playtest-players")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function dispatch(payload: { [string]: any })
	local router = ActionRouter.new()
	PlaytestPlayersAction.register(router)
	return router:Dispatch({ type = "playtestPlayers", sessionId = "session-1", requestId = "r1", payload = payload })
end

describe("playtestPlayers", function()
	it("should list the players", function()
		local response = dispatch({ op = "list" })

		expect(response.type).toEqual("playtestPlayersResult")
		expect(#response.payload.players).toEqual(#game:GetService("Players"):GetPlayers())
	end)

	it("should answer remove at once with no player left to wait for", function()
		local response = dispatch({ op = "remove", kick = {}, names = { "NoSuchPlayer" }, timeoutSec = 5 })

		expect(response.payload.remaining).toEqual({})
	end)

	it("should reject an unknown op", function()
		local response = dispatch({ op = "nope" })

		expect(response.type).toEqual("error")
		expect(response.payload.message).toContain("Unknown playtestPlayers op")
	end)

	it("should reject add without a count", function()
		local response = dispatch({ op = "add", timeoutSec = 5 })

		expect(response.type).toEqual("error")
	end)
end)
