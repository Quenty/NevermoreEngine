--!strict
--[[
	@class capture-screenshot.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local CaptureScreenshotAction = require("capture-screenshot")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("captureScreenshot", function()
	it("should answer CAPABILITY_NOT_SUPPORTED without sendMessage", function()
		local router = ActionRouter.new()
		CaptureScreenshotAction.register(router, nil)

		local response = router:Dispatch({ type = "captureScreenshot", sessionId = "session-1", payload = {} })

		expect(response).toEqual({
			type = "screenshotResult",
			sessionId = "session-1",
			payload = {
				code = "CAPABILITY_NOT_SUPPORTED",
				message = "Screenshot capture requires a sendMessage callback",
			},
		})
	end)
end)
