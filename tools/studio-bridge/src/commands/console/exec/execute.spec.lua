--!strict
--[[
	@class execute.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ActionRouter = require("ActionRouter")
local ExecuteAction = require("execute")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function runScript(code: string): any
	return ExecuteAction.handleExecute({ script = code }, "req-1", "session-1")
end

local function setup(useSendMessage: boolean): any
	local router = ActionRouter.new()
	local sent = {}

	ExecuteAction.register(
		router,
		if useSendMessage
			then function(message)
				table.insert(sent, message)
			end
			else nil
	)

	local controller = {
		router = router,
		sent = sent,
		execute = function(payload: { [string]: any }, requestId: string?)
			return router:Dispatch({
				type = "execute",
				sessionId = "session-1",
				payload = payload,
				requestId = requestId,
			})
		end,
		Destroy = function(_self)
			ExecuteAction._resetQueue()
		end,
	}

	return controller
end

describe("ExecuteAction.handleExecute()", function()
	it("should report success with no return values", function()
		local result = runScript("local _ = 1")

		expect(result).toEqual({ success = true, output = {}, returnValues = {} })
	end)

	it("should capture print and warn output in order", function()
		local result = runScript("print('hello', 1) warn('careful')")

		expect(#result.output).toEqual(2)
		expect(result.output[1].level).toEqual("Print")
		expect(result.output[1].body).toEqual("hello 1")
		expect(result.output[2].level).toEqual("Warning")
		expect(result.output[2].body).toEqual("careful")
	end)

	it("should report the compiler's message for code that does not compile", function()
		local result = runScript("local = ")

		expect(result.success).toEqual(false)
		expect(result.code).toEqual("SCRIPT_LOAD_ERROR")
		expect(result.error).never.toEqual("Failed to compile script")
	end)

	it("should report a runtime error along with the output before it", function()
		local result = runScript("print('before') error('boom')")

		expect(result.success).toEqual(false)
		expect(result.code).toEqual("SCRIPT_RUNTIME_ERROR")
		expect(result.error).toContain("boom")
		expect(result.output[1].body).toEqual("before")
		expect(result.returnValues).toBeNil()
	end)

	it("should reject a request without code", function()
		local result = ExecuteAction.handleExecute({}, "req-1", "session-1")

		expect(result).toEqual({
			success = false,
			error = "Missing code in execute request",
			code = "SCRIPT_LOAD_ERROR",
		})
	end)

	it("should reject code that is not a string", function()
		local result = ExecuteAction.handleExecute({ script = 5 }, "req-1", "session-1")

		expect(result and result.code).toEqual("SCRIPT_LOAD_ERROR")
	end)

	it("should accept code under payload.code and prefer payload.script", function()
		local fromCode = ExecuteAction.handleExecute({ code = "return 'code'" }, "req-1", "session-1")
		local fromBoth =
			ExecuteAction.handleExecute({ script = "return 'script'", code = "return 'code'" }, "req-1", "session-1")

		expect(fromCode and fromCode.returnValues).toEqual({ "code" })
		expect(fromBoth and fromBoth.returnValues).toEqual({ "script" })
	end)

	it("should capture output from threads the script starts", function()
		local result = runScript("task.defer(print, 'deferred')")

		expect(result.output[1].body).toEqual("deferred")
	end)

	it("should capture warnings from threads the script starts", function()
		local result = runScript("task.defer(warn, 'thread warning')")

		expect(result.output[1].level).toEqual("Warning")
		expect(result.output[1].body).toEqual("thread warning")
	end)

	it("should report where a runtime error was thrown", function()
		local result = runScript("local bomb = {}\nfunction bomb.explode()\n\terror('boom')\nend\nbomb.explode()")

		expect(result.code).toEqual("SCRIPT_RUNTIME_ERROR")
		expect(result.error).toContain("exec:3: boom")
		expect(result.traceback).toContain("exec:3")
		expect(result.traceback).toContain("exec:5")
		expect(result.traceback).never.toContain("execute:")
	end)

	it("should cancel a script that outlives its timeout", function()
		local result = ExecuteAction.handleExecute(
			{ script = "task.wait(5) print('too late')", timeoutMs = 50 },
			"req-1",
			"session-1"
		)

		expect(result.success).toEqual(false)
		expect(result.code).toEqual("SCRIPT_TIMEOUT")
		expect(runScript("return 'next'").returnValues).toEqual({ "next" })
	end)
end)

describe("returnValues", function()
	it("should carry every returned value in order", function()
		expect(runScript("return 1, 'two', true").returnValues).toEqual({ 1, "two", true } :: { any })
	end)

	it("should keep nested tables and arrays", function()
		expect(runScript("return { a = { b = 1 } }, { 1, 2, 3 }").returnValues).toEqual({
			{ a = { b = 1 } },
			{ 1, 2, 3 },
		} :: { any })
	end)

	it("should turn non-string keys into strings", function()
		expect(runScript("return { [1] = 'a', [5] = 'b' }").returnValues).toEqual({ { ["1"] = "a", ["5"] = "b" } })
	end)

	it("should keep a returned nil in its position", function()
		expect(runScript("return 1, nil, 3").returnValues).toEqual({ 1, { type = "Nil" }, 3 } :: { any })
	end)

	it("should report a cycle instead of recursing forever", function()
		local result = runScript("local t = {} t.self = t return t")

		expect(result.returnValues[1].self).toEqual({ type = "Unsupported", typeName = "table", toString = "<cycle>" })
	end)

	it("should mark non-finite numbers", function()
		local result = runScript("return math.huge, 0/0")

		expect(result.returnValues[1]).toEqual({ type = "Unsupported", typeName = "number", toString = "inf" })
		expect(result.returnValues[2].type).toEqual("Unsupported")
	end)

	it("should mark functions unsupported", function()
		local result = runScript("return print")

		expect(result.returnValues[1].type).toEqual("Unsupported")
		expect(result.returnValues[1].typeName).toEqual("function")
	end)

	it("should serialize Roblox values", function()
		local result = runScript(
			"return Vector3.new(1, 2, 3), Color3.new(1, 0, 0), Enum.KeyCode.E, UDim2.new(0.5, 10, 1, 20), workspace"
		)

		expect(result.returnValues).toEqual({
			{ type = "Vector3", value = { 1, 2, 3 } },
			{ type = "Color3", value = { 1, 0, 0 } },
			{ type = "EnumItem", enum = "KeyCode", name = "E", value = Enum.KeyCode.E.Value },
			{ type = "UDim2", value = { 0.5, 10, 1, 20 } },
			{ type = "Instance", className = "Workspace", path = "Workspace" },
		} :: { any })
	end)
end)

describe("ExecuteAction.register()", function()
	it("should reply through the router as scriptComplete without sendMessage", function()
		local controller = setup(false)

		local response = controller.execute({ script = "return 1" }, "req-1")

		expect(response and response.type).toEqual("scriptComplete")
		expect(response and response.requestId).toEqual("req-1")
		expect(response and response.payload.returnValues).toEqual({ 1 })

		controller:Destroy()
	end)

	it("should reply through sendMessage and nothing through the router", function()
		local controller = setup(true)

		local response = controller.execute({ script = "return 1" }, "req-1")

		expect(response).toBeNil()
		expect(controller.sent).toEqual({
			{
				type = "scriptComplete",
				sessionId = "session-1",
				requestId = "req-1",
				payload = { success = true, output = {}, returnValues = { 1 } },
			},
		})

		controller:Destroy()
	end)

	it("should leave requestId out when the request had none", function()
		local controller = setup(true)

		controller.execute({ script = "return 1" }, nil)

		expect(controller.sent[1].requestId).toBeNil()

		controller:Destroy()
	end)

	it("should keep answering in order after a failing request", function()
		local controller = setup(true)

		controller.execute({ script = "return 1" }, "req-1")
		controller.execute({ script = "error('boom')" }, "req-2")
		controller.execute({ script = "return 3" }, "req-3")

		expect(#controller.sent).toEqual(3)
		expect(controller.sent[1].requestId).toEqual("req-1")
		expect(controller.sent[2].payload.code).toEqual("SCRIPT_RUNTIME_ERROR")
		expect(controller.sent[3].payload.returnValues).toEqual({ 3 })

		controller:Destroy()
	end)
end)
