--!strict
--[[
	@class ActionRouter.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function createMessage(messageType: string, payload: { [string]: any }?, requestId: string?): ActionRouter.Message
	return {
		type = messageType,
		sessionId = "session-1",
		payload = payload or {},
		requestId = requestId,
	}
end

describe("ActionRouter:Dispatch()", function()
	it("should answer an unknown message type with UNKNOWN_REQUEST", function()
		local router = ActionRouter.new()

		local response = router:Dispatch(createMessage("nope", nil, "req-1"))

		expect(response).toEqual({
			type = "error",
			sessionId = "session-1",
			requestId = "req-1",
			payload = {
				code = "UNKNOWN_REQUEST",
				message = "Unknown message type: nope",
			},
		})
	end)

	it("should wrap a handler's return as <type>Result", function()
		local router = ActionRouter.new()
		router:register("ping", function(payload)
			return { echo = payload.value }
		end)

		local response = router:Dispatch(createMessage("ping", { value = 5 }, "req-2"))

		expect(response).toEqual({
			type = "pingResult",
			sessionId = "session-1",
			requestId = "req-2",
			payload = { echo = 5 },
		})
	end)

	it("should use the response type set for the message type", function()
		local router = ActionRouter.new()
		router:register("ping", function()
			return {}
		end)
		router:setResponseType("ping", "pong")

		local response = router:Dispatch(createMessage("ping"))

		expect(response and response.type).toEqual("pong")
	end)

	it("should pass the payload, requestId, and sessionId to the handler", function()
		local router = ActionRouter.new()
		local received = {}
		router:register("ping", function(payload, requestId, sessionId)
			received = { payload = payload, requestId = requestId, sessionId = sessionId }
			return nil
		end)

		router:Dispatch(createMessage("ping", { value = 1 }, "req-3"))

		expect(received).toEqual({ payload = { value = 1 }, requestId = "req-3", sessionId = "session-1" })
	end)

	it("should pass an empty requestId when the message has none", function()
		local router = ActionRouter.new()
		local receivedRequestId = nil
		router:register("ping", function(_payload, requestId)
			receivedRequestId = requestId
			return nil
		end)

		router:Dispatch(createMessage("ping"))

		expect(receivedRequestId).toEqual("")
	end)

	it("should send nothing when the handler returns nil", function()
		local router = ActionRouter.new()
		router:register("ping", function()
			return nil
		end)

		expect(router:Dispatch(createMessage("ping"))).toBeNil()
	end)

	it("should answer a throwing handler with INTERNAL_ERROR", function()
		local router = ActionRouter.new()
		router:register("ping", function()
			error("boom")
		end)

		local response = router:Dispatch(createMessage("ping", nil, "req-4"))

		expect(response and response.type).toEqual("error")
		expect(response and response.requestId).toEqual("req-4")
		expect(response and response.payload.code).toEqual("INTERNAL_ERROR")
		expect(response and response.payload.message).toContain("boom")
	end)
end)

describe("ActionRouter:RegisterAction()", function()
	it("should install a module through its register function", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction(
			"greet",
			[[
				return {
					register = function(router)
						router:register("greet", function(payload)
							return { greeting = "hi " .. payload.name }
						end)
					end,
				}
			]],
			nil,
			nil,
			nil,
			"hash-1"
		)

		expect(ok).toEqual(true)
		expect(err).toBeNil()

		local response = router:Dispatch(createMessage("greet", { name = "bob" }))
		expect(response and response.payload).toEqual({ greeting = "hi bob" })
	end)

	it("should hand sendMessage and logBuffer to the module's register", function()
		local router = ActionRouter.new()
		local sendMessage = function() end
		local logBuffer = {}
		local received: { [string]: any } = {}
		router:register("capture", function(payload)
			received = payload
			return nil
		end)

		router:RegisterAction(
			"probe",
			[[
				return {
					register = function(router, sendMessage, logBuffer)
						router:Dispatch({
							type = "capture",
							sessionId = "s",
							payload = { sendMessage = sendMessage, logBuffer = logBuffer },
						})
					end,
				}
			]],
			sendMessage,
			logBuffer
		)

		expect(received.sendMessage).toBe(sendMessage)
		expect(received.logBuffer).toBe(logBuffer)
	end)

	it("should register a bare function under the action name", function()
		local router = ActionRouter.new()

		local ok = router:RegisterAction("double", "return function(payload) return { value = payload.value * 2 } end")

		expect(ok).toEqual(true)

		local response = router:Dispatch(createMessage("double", { value = 21 }))
		expect(response and response.payload).toEqual({ value = 42 })
	end)

	it("should apply the response type override", function()
		local router = ActionRouter.new()

		router:RegisterAction("double", "return function() return {} end", nil, nil, "doubled")

		local response = router:Dispatch(createMessage("double"))
		expect(response and response.type).toEqual("doubled")
	end)

	it("should fail on source that does not compile", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction("broken", "return {")

		expect(ok).toEqual(false)
		expect(err).toContain("Failed to load action source")
	end)

	it("should fail on a module that throws while loading", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction("broken", "error('load boom')")

		expect(ok).toEqual(false)
		expect(err).toContain("Failed to execute action module")
	end)

	it("should fail on a module whose register throws", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction("broken", "return { register = function() error('register boom') end }")

		expect(ok).toEqual(false)
		expect(err).toContain("register() failed")
	end)

	it("should fail on a module that returns neither a table nor a function", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction("broken", "return 5")

		expect(ok).toEqual(false)
		expect(err).toContain("must return a table")
	end)

	it("should skip reloading when the same hash is installed", function()
		local router = ActionRouter.new()
		router:RegisterAction("counter", "return function() return { version = 1 } end", nil, nil, nil, "hash-1")

		local ok =
			router:RegisterAction("counter", "return function() return { version = 2 } end", nil, nil, nil, "hash-1")

		expect(ok).toEqual(true)

		local response = router:Dispatch(createMessage("counter"))
		expect(response and response.payload).toEqual({ version = 1 })
	end)

	it("should replace the action and tear the old module down on a new hash", function()
		local router = ActionRouter.new()
		local tornDown = {}
		router:register("recordTeardown", function(payload)
			table.insert(tornDown, payload.name)
			return nil
		end)

		router:RegisterAction(
			"multi",
			[[
				local router
				return {
					register = function(r)
						router = r
						r:register("multiA", function() return { version = 1 } end)
						r:register("multiB", function() return { version = 1 } end)
					end,
					teardown = function()
						router:Dispatch({ type = "recordTeardown", sessionId = "s", payload = { name = "v1" } })
					end,
				}
			]],
			nil,
			nil,
			nil,
			"hash-1"
		)

		router:RegisterAction(
			"multi",
			[[
				return {
					register = function(r)
						r:register("multiA", function() return { version = 2 } end)
					end,
				}
			]],
			nil,
			nil,
			nil,
			"hash-2"
		)

		expect(tornDown).toEqual({ "v1" })

		local responseA = router:Dispatch(createMessage("multiA"))
		local responseB = router:Dispatch(createMessage("multiB"))
		expect(responseA and responseA.payload).toEqual({ version = 2 })
		expect(responseB and responseB.payload.code).toEqual("UNKNOWN_REQUEST")
	end)
end)

describe("ActionRouter:Compile()", function()
	it("should compile source into a callable function", function()
		local router = ActionRouter.new()

		local fn = router:Compile("return 1 + 2")

		expect(fn()).toEqual(3)
	end)

	it("should return the compile error for invalid source", function()
		local router = ActionRouter.new()

		local fn, err = router:Compile("local x = = 1", "=test")

		expect(fn).toBeNil()
		expect(err).toEqual(expect.stringContaining("Expected identifier"))
	end)
end)

describe("ActionRouter:Destroy()", function()
	it("should tear down every action and drop all handlers", function()
		local router = ActionRouter.new()
		local tornDown = {}
		router:register("recordTeardown", function(payload)
			table.insert(tornDown, payload.name)
			return nil
		end)

		router:RegisterAction(
			"action",
			[[
				local router
				return {
					register = function(r)
						router = r
						r:register("actionA", function() return {} end)
					end,
					teardown = function()
						router:Dispatch({ type = "recordTeardown", sessionId = "s", payload = { name = "action" } })
					end,
				}
			]],
			nil,
			nil,
			nil,
			"hash-1"
		)

		router:Destroy()

		expect(tornDown).toEqual({ "action" })
		expect(router:GetInstalledActions()).toEqual({})
		local response = router:Dispatch(createMessage("actionA"))
		expect(response and response.payload.code).toEqual("UNKNOWN_REQUEST")
	end)
end)

describe("ActionRouter:GetInstalledActions()", function()
	it("should map each hashed action to its hash", function()
		local router = ActionRouter.new()
		router:RegisterAction("a", "return function() return {} end", nil, nil, nil, "hash-a")
		router:RegisterAction("b", "return function() return {} end", nil, nil, nil, "hash-b")
		router:RegisterAction("unhashed", "return function() return {} end")

		expect(router:GetInstalledActions()).toEqual({ a = "hash-a", b = "hash-b" })
	end)
end)

describe("ActionRouter:GetActionHandlerNames()", function()
	it("should list the handlers an action registered", function()
		local router = ActionRouter.new()
		router:RegisterAction(
			"multi",
			[[
				return {
					register = function(r)
						r:register("multiA", function() return {} end)
						r:register("multiB", function() return {} end)
					end,
				}
			]],
			nil,
			nil,
			nil,
			"hash-1"
		)

		local handlerNames = router:GetActionHandlerNames("multi")
		assert(handlerNames, "No handler names")
		table.sort(handlerNames)

		expect(handlerNames).toEqual({ "multiA", "multiB" })
	end)

	it("should return nil for an action that is not installed", function()
		local router = ActionRouter.new()

		expect(router:GetActionHandlerNames("missing")).toBeNil()
	end)
end)
