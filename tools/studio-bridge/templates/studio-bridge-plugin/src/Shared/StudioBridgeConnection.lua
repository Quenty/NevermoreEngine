--!strict
--[=[
	One open WebSocket to the bridge. Registers the plugin, dispatches incoming
	messages through an [ActionRouter] and sends back the responses, and sends a
	heartbeat every 15 seconds until destroyed.

	A `shutdown` message closes the socket, and a closed socket destroys this.

	@class StudioBridgeConnection
]=]

local HttpService = game:GetService("HttpService")

local HEARTBEAT_INTERVAL_SEC = 15
local LOG_PREFIX = "[StudioBridge]"

local StudioBridgeConnection = {}
StudioBridgeConnection.ClassName = "StudioBridgeConnection"
StudioBridgeConnection.__index = StudioBridgeConnection

--[=[
	The members of a WebStreamClient this uses. Specs pass a fake shaped like it.

	@interface WebSocket
	.Send (self, data: string) -> ()
	.Close (self) -> ()
	.MessageReceived RBXScriptSignal
	.Closed RBXScriptSignal
	@within StudioBridgeConnection
]=]
export type WebSocket = {
	Send: (self: any, data: string) -> (),
	Close: (self: any) -> (),
	MessageReceived: any,
	Closed: any,
}

export type StudioBridgeConnectionOptions = {
	webSocket: WebSocket,
	router: any,
	sessionId: string,
	registerPayload: { [string]: any },
}

export type StudioBridgeConnection = typeof(setmetatable(
	{} :: {
		_webSocket: WebSocket,
		_router: any,
		_sessionId: string,
		_registerPayload: { [string]: any },
		_isOpen: boolean,
		_startClock: number,
		_signalConnections: { any },
		_heartbeatThread: thread?,
	},
	{} :: typeof({ __index = StudioBridgeConnection })
))

--[=[
	Wires an opened WebSocket and sends the `register` message.
]=]
function StudioBridgeConnection.new(options: StudioBridgeConnectionOptions): StudioBridgeConnection
	local self: StudioBridgeConnection = setmetatable({} :: any, StudioBridgeConnection)

	self._webSocket = assert(options.webSocket, "No webSocket")
	self._router = assert(options.router, "No router")
	self._sessionId = assert(options.sessionId, "No sessionId")
	self._registerPayload = assert(options.registerPayload, "No registerPayload")
	self._isOpen = true
	self._startClock = os.clock()
	self._signalConnections = {}

	table.insert(
		self._signalConnections,
		self._webSocket.MessageReceived:Connect(function(rawData: string)
			self:_handleRawMessage(rawData)
		end)
	)
	table.insert(
		self._signalConnections,
		self._webSocket.Closed:Connect(function()
			self:Destroy()
		end)
	)

	self:Send({
		type = "register",
		sessionId = self._sessionId,
		payload = self._registerPayload,
	})

	self._heartbeatThread = task.spawn(function()
		while self._isOpen do
			self:_sendHeartbeat()
			task.wait(HEARTBEAT_INTERVAL_SEC)
		end
	end)

	return self
end

--[=[
	Returns whether the socket is still open.
]=]
function StudioBridgeConnection.IsOpen(self: StudioBridgeConnection): boolean
	return self._isOpen
end

--[=[
	Encodes and sends a message. Does nothing once the socket is closed, and
	never throws, since action handlers call this from their own threads.
]=]
function StudioBridgeConnection.Send(self: StudioBridgeConnection, message: { [string]: any })
	if not self._isOpen then
		return
	end

	local ok, err = pcall(function()
		self._webSocket:Send(HttpService:JSONEncode(message))
	end)
	if not ok then
		warn(`{LOG_PREFIX} Failed to send {tostring(message.type)}: {tostring(err)}`)
	end
end

function StudioBridgeConnection._sendHeartbeat(self: StudioBridgeConnection)
	self:Send({
		type = "heartbeat",
		sessionId = self._sessionId,
		payload = {
			uptimeMs = math.floor((os.clock() - self._startClock) * 1000),
			state = self._registerPayload.state,
			pendingRequests = 0,
		},
	})
end

function StudioBridgeConnection._handleRawMessage(self: StudioBridgeConnection, rawData: string)
	local ok, err = pcall(StudioBridgeConnection._dispatchRawMessage, self, rawData)
	if not ok then
		warn(`{LOG_PREFIX} MessageReceived handler error: {tostring(err)}`)
	end
end

function StudioBridgeConnection._dispatchRawMessage(self: StudioBridgeConnection, rawData: string)
	local decodeOk, message = pcall(HttpService.JSONDecode, HttpService, rawData)
	if not decodeOk or type(message) ~= "table" or type(message.type) ~= "string" then
		print(`{LOG_PREFIX} Failed to decode message: {string.sub(tostring(rawData), 1, 200)}`)
		return
	end

	print(`{LOG_PREFIX} Received: {message.type} (requestId={string.sub(tostring(message.requestId), 1, 8)}...)`)

	if message.type == "shutdown" then
		self:_close()
		return
	end

	local response = self._router:Dispatch(message)
	if not response then
		print(`{LOG_PREFIX} No response for: {message.type}`)
		return
	end

	local encoded = HttpService:JSONEncode(response)
	print(`{LOG_PREFIX} Sending: {response.type} ({#encoded} bytes)`)
	self._webSocket:Send(encoded)
end

function StudioBridgeConnection._close(self: StudioBridgeConnection)
	self._isOpen = false
	pcall(function()
		self._webSocket:Close()
	end)
end

--[=[
	Stops the heartbeat and stops listening to the socket. Does not close the
	socket, since by then it is usually already closed.
]=]
function StudioBridgeConnection.Destroy(self: StudioBridgeConnection)
	self._isOpen = false

	for _, connection in self._signalConnections do
		connection:Disconnect()
	end
	table.clear(self._signalConnections)

	local heartbeatThread = self._heartbeatThread
	self._heartbeatThread = nil
	if heartbeatThread and coroutine.status(heartbeatThread) == "suspended" then
		task.cancel(heartbeatThread)
	end
end

return StudioBridgeConnection
