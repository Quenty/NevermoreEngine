--!strict
--[[
	@class ActionRouter.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

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

	it("should answer a handler's failure as an error with its code", function()
		local router = ActionRouter.new()
		router:register("ping", function()
			return { success = false, code = "INSTANCE_NOT_FOUND", message = "Instance not found" }
		end)

		local response = router:Dispatch(createMessage("ping", nil, "req-5"))

		expect(response).toEqual({
			type = "error",
			sessionId = "session-1",
			requestId = "req-5",
			payload = {
				code = "INSTANCE_NOT_FOUND",
				message = "Instance not found",
			},
		})
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
		expect(err).toContain("Failed to load action module")
		expect(err).toContain("Expected")
	end)

	it("should fail on a module that throws while loading", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction("broken", "error('load boom')")

		expect(ok).toEqual(false)
		expect(err).toContain("Failed to load action module")
		expect(err).toContain("load boom")
	end)

	it("should load a fixed push of a module whose last push failed", function()
		local router = ActionRouter.new()
		router:RegisterAction("flaky", "error('load boom')", nil, nil, nil, "hash-1")

		local ok =
			router:RegisterAction("flaky", "return function() return { fixed = true } end", nil, nil, nil, "hash-2")

		expect(ok).toEqual(true)
		local response = router:Dispatch(createMessage("flaky"))
		expect(response and response.payload).toEqual({ fixed = true })
	end)

	it("should install a module that registers no handlers", function()
		local router = ActionRouter.new()

		local ok, err = router:RegisterAction("Shared", "return { value = 1 }", nil, nil, nil, "hash-1")

		expect(err).toBeNil()
		expect(ok).toEqual(true)
		expect(router:GetInstalledActions()).toEqual({ Shared = "hash-1" })
		expect(router:GetActionHandlerNames("Shared")).toEqual({})
	end)

	it("should let pushed modules require one another and the plugin's modules by name", function()
		local router = ActionRouter.new()
		local folder = Instance.new("Folder")
		folder.Name = `ActionRouterSpec{HttpService:GenerateGUID(false)}`
		folder.Parent = script.Parent
		router:SetModuleFolder(folder)

		local libraryOk, libraryErr = router:RegisterAction(
			"ActionRouterSpecLibrary",
			[[
				local require = require(script.Parent.loader).load(script)
				local MessageBuffer = require("MessageBuffer")
				return { createBuffer = function() return MessageBuffer.new(2) end }
			]],
			nil,
			nil,
			nil,
			"hash-library"
		)
		local actionOk, actionErr = router:RegisterAction(
			"uses-library",
			[[
				local require = require(script.Parent.loader).load(script)
				local ActionRouterSpecLibrary = require("ActionRouterSpecLibrary")
				return function()
					local buffer = ActionRouterSpecLibrary.createBuffer()
					buffer:Push({ level = "Print", body = "hi", timestamp = 0 })
					return { size = buffer:GetCount() }
				end
			]],
			nil,
			nil,
			nil,
			"hash-action"
		)

		local response = router:Dispatch(createMessage("uses-library"))
		folder:Destroy()

		expect(libraryErr).toBeNil()
		expect(libraryOk).toEqual(true)
		expect(actionErr).toBeNil()
		expect(actionOk).toEqual(true)
		expect(response and response.payload).toEqual({ size = 1 })
	end)

	it("should require a module already in the folder with the same hash", function()
		local router = ActionRouter.new()
		local planted = Instance.new("ModuleScript")
		planted.Name = "planted"
		planted.Source = "return function() return { from = 'planted' } end"
		planted:SetAttribute("Hash", "hash-1")
		planted.Parent = router:GetModuleFolder()

		local ok = router:RegisterAction(
			"planted",
			"return function() return { from = 'pushed' } end",
			nil,
			nil,
			nil,
			"hash-1"
		)

		expect(ok).toEqual(true)
		local response = router:Dispatch(createMessage("planted"))
		expect(response and response.payload).toEqual({ from = "planted" })
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

	it("should keep the old action running when its update fails to load", function()
		local router = ActionRouter.new()
		router:RegisterAction(
			"kept",
			[[return { register = function(r) r:register("kept", function() return { version = 1 } end) end }]],
			nil,
			nil,
			nil,
			"hash-1"
		)

		local ok = router:RegisterAction("kept", "return {", nil, nil, nil, "hash-2")

		expect(ok).toEqual(false)
		expect(router:GetInstalledActions().kept).toEqual("hash-1")
		expect(router:GetActionHandlerNames("kept")).toEqual({ "kept" })
		local response = router:Dispatch(createMessage("kept"))
		expect(response and response.payload).toEqual({ version = 1 })
	end)

	it("should keep the old action running when its update's register throws", function()
		local router = ActionRouter.new()
		local tornDown = {}
		router:register("recordTeardown", function(payload)
			table.insert(tornDown, payload.name)
			return nil
		end)
		router:RegisterAction(
			"kept",
			[[
				local router
				return {
					register = function(r)
						router = r
						r:register("kept", function() return { version = 1 } end)
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

		local ok, err = router:RegisterAction(
			"kept",
			[[
				return {
					register = function(r)
						r:register("kept", function() return { version = 2 } end)
						r:register("keptExtra", function() return {} end)
						error("register boom")
					end,
				}
			]],
			nil,
			nil,
			nil,
			"hash-2"
		)

		expect(ok).toEqual(false)
		expect(err).toContain("register() failed")
		expect(tornDown).toEqual({})
		expect(router:GetInstalledActions().kept).toEqual("hash-1")
		expect(router:GetActionHandlerNames("kept")).toEqual({ "kept" })
		local response = router:Dispatch(createMessage("kept"))
		local extraResponse = router:Dispatch(createMessage("keptExtra"))
		expect(response and response.payload).toEqual({ version = 1 })
		expect(extraResponse and extraResponse.payload.code).toEqual("UNKNOWN_REQUEST")
	end)

	it("should keep the old action running when its update returns the wrong type", function()
		local router = ActionRouter.new()
		router:RegisterAction("kept", "return function() return { version = 1 } end", nil, nil, nil, "hash-1")

		local ok = router:RegisterAction("kept", "return 5", nil, nil, nil, "hash-2")

		expect(ok).toEqual(false)
		expect(router:GetInstalledActions().kept).toEqual("hash-1")
		local response = router:Dispatch(createMessage("kept"))
		expect(response and response.payload).toEqual({ version = 1 })
	end)

	it("should keep the old module resolvable by name when its update fails to load", function()
		local router = ActionRouter.new()
		local folder = Instance.new("Folder")
		folder.Name = `ActionRouterSpec{HttpService:GenerateGUID(false)}`
		folder.Parent = script.Parent
		router:SetModuleFolder(folder)

		router:RegisterAction("ActionRouterSpecKeptLibrary", "return { version = 1 }", nil, nil, nil, "hash-1")
		local brokenOk =
			router:RegisterAction("ActionRouterSpecKeptLibrary", "error('load boom')", nil, nil, nil, "hash-2")
		local actionOk, actionErr = router:RegisterAction(
			"uses-kept-library",
			[[
				local require = require(script.Parent.loader).load(script)
				local ActionRouterSpecKeptLibrary = require("ActionRouterSpecKeptLibrary")
				return function()
					return { version = ActionRouterSpecKeptLibrary.version }
				end
			]],
			nil,
			nil,
			nil,
			"hash-action"
		)

		local response = router:Dispatch(createMessage("uses-kept-library"))
		local library = folder:FindFirstChild("ActionRouterSpecKeptLibrary")
		local libraryHash = library and library:GetAttribute("Hash")
		folder:Destroy()

		expect(brokenOk).toEqual(false)
		expect(actionErr).toBeNil()
		expect(actionOk).toEqual(true)
		expect(response and response.payload).toEqual({ version = 1 })
		expect(libraryHash).toEqual("hash-1")
	end)
end)

describe("ActionRouter:GetFailedAction()", function()
	it("should remember the hash and error of a push that failed", function()
		local router = ActionRouter.new()

		router:RegisterAction("broken", "return 5", nil, nil, nil, "hash-1")

		expect(router:GetFailedAction("broken")).toEqual({
			hash = "hash-1",
			error = "Action module must return a table or a function",
		})
	end)

	it("should forget the failure once a later push installs", function()
		local router = ActionRouter.new()
		router:RegisterAction("flaky", "return 5", nil, nil, nil, "hash-1")

		router:RegisterAction("flaky", "return function() return {} end", nil, nil, nil, "hash-2")

		expect(router:GetFailedAction("flaky")).toBeNil()
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

describe("ActionRouter._compileWithModuleScript()", function()
	it("should keep a top-level return legal by wrapping the source on its first line", function()
		local fn = ActionRouter._compileWithModuleScript("return 1 + 2", "=wrapped")

		expect(fn()).toEqual(3)
	end)

	it("should keep line numbers unchanged by wrapping the source on its first line", function()
		local fn = ActionRouter._compileWithModuleScript("\n\nerror('third line')", "=lines")

		local ok, err = pcall(fn)

		expect(ok).toEqual(false)
		expect(tostring(err)).toContain(":3: third line")
	end)
end)

describe("ActionRouter._requireModuleScript()", function()
	it("should return the load error, which reaches the output a frame after require fails", function()
		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Name = "LoadErrorSpec"
		moduleScript.Source = "error('load error text')"

		local ok, err = ActionRouter._requireModuleScript(moduleScript)
		moduleScript:Destroy()

		expect(ok).toEqual(false)
		expect(err).toContain("load error text")
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
