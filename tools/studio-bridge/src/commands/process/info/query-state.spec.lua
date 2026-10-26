--!strict
--[[
	@class query-state.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")
local QueryStateAction = require("query-state")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("queryState", function()
	it("should answer stateResult with the run mode and the open place", function()
		local router = ActionRouter.new()
		QueryStateAction.register(router)

		local response = router:Dispatch({ type = "queryState", sessionId = "session-1", payload = {} })

		expect(response).toEqual({
			type = "stateResult",
			sessionId = "session-1",
			payload = {
				state = "Edit",
				placeName = game.Name,
				placeId = game.PlaceId,
				gameId = game.GameId,
			},
		})
	end)
end)
