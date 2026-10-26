--!strict
--[[
	@class StudioBridgeConnection.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")
local StudioBridgeConnection = require("StudioBridgeConnection")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local REGISTER_PAYLOAD = table.freeze({
	pluginVersion = "test",
	state = "Edit",
})

local function createFakeSignal(): any
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self, handler)
			table.insert(handlers, handler)
			return {
				Disconnect = function()
					local index = table.find(handlers, handler)
					if index then
						table.remove(handlers, index)
					end
				end,
			}
		end,
		Fire = function(_self, ...)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		GetHandlerCount = function()
			return #handlers
		end,
	}
end

local function setup(): any
	local sentData: { string } = {}
	local webSocket: any = {
		closeCount = 0,
		MessageReceived = createFakeSignal(),
		Closed = createFakeSignal(),
	}

	function webSocket.Send(_self, data: string)
		table.insert(sentData, data)
	end

	function webSocket.Close(self)
		self.closeCount += 1
	end

	local router = ActionRouter.new()
	local connection = StudioBridgeConnection.new({
		webSocket = webSocket :: any,
		router = router,
		sessionId = "session-1",
		registerPayload = REGISTER_PAYLOAD,
	})

	local controller = {
		webSocket = webSocket,
		router = router,
		connection = connection,
		receive = function(message: { [string]: any })
			webSocket.MessageReceived:Fire(HttpService:JSONEncode(message))
		end,
		getSent = function(): { any }
			local messages = {}
			for _, data in sentData do
				table.insert(messages, HttpService:JSONDecode(data))
			end
			return messages
		end,
		clearSent = function()
			table.clear(sentData)
		end,
		Destroy = function(_self)
			connection:Destroy()
		end,
	}

	return controller
end

describe("StudioBridgeConnection.new()", function()
	it("should register, then send a heartbeat", function()
		local controller = setup()

		local sent = controller.getSent()

		expect(#sent).toEqual(2)
		expect(sent[1]).toEqual({
			type = "register",
			sessionId = "session-1",
			payload = { pluginVersion = "test", state = "Edit" },
		})
		expect(sent[2].type).toEqual("heartbeat")
		expect(sent[2].sessionId).toEqual("session-1")
		expect(sent[2].payload.state).toEqual("Edit")
		expect(sent[2].payload.pendingRequests).toEqual(0)
		expect(type(sent[2].payload.uptimeMs)).toEqual("number")
		expect(controller.connection:IsOpen()).toEqual(true)

		controller:Destroy()
	end)
end)

describe("StudioBridgeConnection message handling", function()
	it("should dispatch a message and send back the response", function()
		local controller = setup()
		controller.router:register("ping", function(payload)
			return { echo = payload.value }
		end)
		controller.clearSent()

		controller.receive({ type = "ping", sessionId = "session-1", requestId = "req-1", payload = { value = 3 } })

		expect(controller.getSent()).toEqual({
			{
				type = "pingResult",
				sessionId = "session-1",
				requestId = "req-1",
				payload = { echo = 3 },
			},
		})

		controller:Destroy()
	end)

	it("should send nothing when the handler returns nil", function()
		local controller = setup()
		controller.router:register("quiet", function()
			return nil
		end)
		controller.clearSent()

		controller.receive({ type = "quiet", sessionId = "session-1", payload = {} })

		expect(controller.getSent()).toEqual({})

		controller:Destroy()
	end)

	it("should ignore a message that is not JSON", function()
		local controller = setup()
		controller.clearSent()

		controller.webSocket.MessageReceived:Fire("not json")

		expect(controller.getSent()).toEqual({})
		expect(controller.connection:IsOpen()).toEqual(true)

		controller:Destroy()
	end)

	it("should close the socket on shutdown and stop sending", function()
		local controller = setup()
		controller.clearSent()

		controller.receive({ type = "shutdown", sessionId = "session-1", payload = {} })
		controller.connection:Send({ type = "late" })

		expect(controller.webSocket.closeCount).toEqual(1)
		expect(controller.connection:IsOpen()).toEqual(false)
		expect(controller.getSent()).toEqual({})

		controller:Destroy()
	end)
end)

describe("StudioBridgeConnection socket close", function()
	it("should stop listening once the socket closes", function()
		local controller = setup()

		controller.webSocket.Closed:Fire()

		expect(controller.connection:IsOpen()).toEqual(false)
		expect(controller.webSocket.MessageReceived.GetHandlerCount()).toEqual(0)
		expect(controller.webSocket.Closed.GetHandlerCount()).toEqual(0)

		controller:Destroy()
	end)
end)

describe("StudioBridgeConnection:Destroy()", function()
	it("should disconnect from the socket without closing it", function()
		local controller = setup()

		controller:Destroy()

		expect(controller.connection:IsOpen()).toEqual(false)
		expect(controller.webSocket.closeCount).toEqual(0)
		expect(controller.webSocket.MessageReceived.GetHandlerCount()).toEqual(0)
	end)
end)
