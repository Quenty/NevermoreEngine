--!strict
--[[
	@class run-playtest-script.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")
local RunPlaytestScriptAction = require("run-playtest-script")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function dispatch(payload: { [string]: any }): any
	local router = ActionRouter.new()
	RunPlaytestScriptAction.register(router, function() end)

	return router:Dispatch({
		type = "runPlaytestScript",
		sessionId = "session-1",
		requestId = "req-1",
		payload = payload,
	})
end

describe("runPlaytestScript", function()
	it("should fail a script that does not compile without starting a playtest", function()
		local response = dispatch({ mode = "run", script = "local x = = 1", runnerSource = "", timeoutSec = 10 })

		expect(response.type).toEqual("scriptComplete")
		expect(response.payload.success).toEqual(false)
		expect(response.payload.code).toEqual("SCRIPT_LOAD_ERROR")
	end)

	it("should reject an unknown mode", function()
		local response = dispatch({ mode = "nope", script = "return 1", runnerSource = "", timeoutSec = 10 })

		expect(response.type).toEqual("error")
		expect(response.payload.message).toEqual(expect.stringContaining("Unknown playtest mode"))
	end)
end)
