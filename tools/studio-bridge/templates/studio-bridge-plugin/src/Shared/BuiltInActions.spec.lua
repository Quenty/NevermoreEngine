--!strict
--[[
	@class BuiltInActions.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local BuiltInActions = require("BuiltInActions")
local Jest = require("Jest")
local StudioBridgeLogUtils = require("StudioBridgeLogUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local ECHO_SOURCE = "return function(payload) return { echo = payload.value } end"

local function setup(): any
	local controller = {
		router = ActionRouter.new(),
		sent = {},
		logBuffer = {},
	}

	BuiltInActions.register(controller.router, function(message)
		table.insert(controller.sent, message)
	end, controller.logBuffer)

	function controller.dispatch(messageType: string, payload: { [string]: any }): ActionRouter.Message?
		return controller.router:Dispatch({
			type = messageType,
			sessionId = "session-1",
			payload = payload,
			requestId = "req-1",
		})
	end

	return controller
end

describe("registerAction", function()
	it("should install the action and answer registerActionResult", function()
		local controller = setup()

		local response = controller.dispatch("registerAction", { name = "echo", source = ECHO_SOURCE, hash = "hash-1" })

		expect(response and response.type).toEqual("registerActionResult")
		expect(response and response.payload).toEqual({
			name = "echo",
			success = true,
			skipped = false,
			hash = "hash-1",
			handlers = { "echo" },
		})

		local echoResponse = controller.dispatch("echo", { value = 7 })
		expect(echoResponse and echoResponse.payload).toEqual({ echo = 7 })
	end)

	it("should skip an action already installed with the same hash", function()
		local controller = setup()
		controller.dispatch("registerAction", { name = "echo", source = ECHO_SOURCE, hash = "hash-1" })

		local response =
			controller.dispatch("registerAction", { name = "echo", source = "error('unused')", hash = "hash-1" })

		expect(response and response.payload).toEqual({
			name = "echo",
			success = true,
			skipped = true,
			hash = "hash-1",
			handlers = { "echo" },
		})
	end)

	it("should hand its sendMessage and logBuffer to installed actions", function()
		local controller = setup()

		controller.dispatch("registerAction", {
			name = "probe",
			source = [[
				return {
					register = function(router, sendMessage, logBuffer)
						sendMessage({ type = "probe", sawLogBuffer = logBuffer ~= nil })
					end,
				}
			]],
		})

		expect(controller.sent).toEqual({ { type = "probe", sawLogBuffer = true } })
	end)

	it("should apply the requested response type", function()
		local controller = setup()
		controller.dispatch("registerAction", { name = "echo", source = ECHO_SOURCE, responseType = "echoed" })

		local response = controller.dispatch("echo", { value = 1 })

		expect(response and response.type).toEqual("echoed")
	end)

	it("should report a failed install", function()
		local controller = setup()

		local response =
			controller.dispatch("registerAction", { name = "broken", source = "return {", hash = "hash-1" })

		expect(response and response.payload.success).toEqual(false)
		expect(response and response.payload.handlers).toEqual({})
		expect(response and response.payload.error).toContain("Failed to load action source")
	end)

	it("should reject a payload without a name and source", function()
		local controller = setup()

		local response = controller.dispatch("registerAction", { name = "nosource" })

		expect(response and response.payload).toEqual({
			name = "nosource",
			success = false,
			error = "Invalid registerAction payload: name and source are required strings",
		})
	end)
end)

describe("syncActions", function()
	it("should list the actions that are missing or out of date", function()
		local controller = setup()
		controller.dispatch("registerAction", { name = "current", source = ECHO_SOURCE, hash = "hash-current" })
		controller.dispatch("registerAction", { name = "stale", source = ECHO_SOURCE, hash = "hash-old" })

		local response = controller.dispatch("syncActions", {
			actions = {
				current = "hash-current",
				stale = "hash-new",
				missing = "hash-missing",
			},
		})

		assert(response, "No response")
		table.sort(response.payload.needed)

		expect(response.type).toEqual("syncActionsResult")
		expect(response.payload.needed).toEqual({ "missing", "stale" })
		expect(response.payload.installed).toEqual({ current = "hash-current", stale = "hash-old" })
	end)

	it("should need nothing when sent no actions", function()
		local controller = setup()

		local response = controller.dispatch("syncActions", {})

		expect(response and response.payload).toEqual({ needed = {}, installed = {} })
	end)

	it("should follow the bridge's verbose flag for plugin logging", function()
		local controller = setup()

		controller.dispatch("syncActions", { verbose = true })
		expect(StudioBridgeLogUtils.isVerbose()).toEqual(true)

		controller.dispatch("syncActions", {})
		expect(StudioBridgeLogUtils.isVerbose()).toEqual(false)
	end)
end)
