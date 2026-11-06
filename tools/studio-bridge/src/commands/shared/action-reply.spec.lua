--!strict
--[[
	@class action-reply.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionReply = require("action-reply")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ActionReply.build", function()
	it("should carry a result under the response type", function()
		local message = ActionReply.build("session-1", "request-1", "thingResult", { count = 2 })

		expect(message).toEqual({
			type = "thingResult",
			sessionId = "session-1",
			requestId = "request-1",
			payload = { count = 2 },
		})
	end)

	it("should turn a failure into an error message", function()
		local message =
			ActionReply.build("session-1", "request-1", "thingResult", ActionReply.failure("BAD", "bad thing"))

		expect(message.type).toEqual("error")
		expect(message.payload).toEqual({ code = "BAD", message = "bad thing" })
	end)

	it("should leave out an empty request id", function()
		local message = ActionReply.build("session-1", "", "thingResult", {})

		expect(message.requestId).toBeNil()
	end)
end)
