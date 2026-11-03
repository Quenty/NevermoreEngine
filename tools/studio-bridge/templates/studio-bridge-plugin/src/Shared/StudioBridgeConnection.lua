--!strict
--[=[
	One open WebSocket to the bridge. Registers the plugin, dispatches incoming
	messages through an [ActionRouter] and sends back the responses, and sends a
	heartbeat every 15 seconds until destroyed.

	A `shutdown` message closes the socket, and a closed socket destroys this.

	A reply over `maxMessageBytes` (256 MiB by default) is replaced with a
	`RESULT_TOO_LARGE` error for its request. Studio sends far larger messages,
	but the bridge closes a socket that sends it more than it accepts, which
	would fail every request in flight.

	@class StudioBridgeConnection
]=]

local HttpService = game:GetService("HttpService")

local StudioBridgeLogUtils = require(script.Parent.StudioBridgeLogUtils)

local HEARTBEAT_INTERVAL_SEC = 15
local DEFAULT_MAX_MESSAGE_BYTES = 256 * 1024 * 1024

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
	maxMessageBytes: number?,
}

export type StudioBridgeConnection = typeof(setmetatable(
	{} :: {
		_webSocket: WebSocket,
		_router: any,
		_sessionId: string,
		_registerPayload: { [string]: any },
		_maxMessageBytes: number,
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
	self._maxMessageBytes = options.maxMessageBytes or DEFAULT_MAX_MESSAGE_BYTES
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
		self._webSocket:Send(self:_encode(message))
	end)
	if not ok then
		StudioBridgeLogUtils.warn(`Failed to send {tostring(message.type)}: {tostring(err)}`)
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
		StudioBridgeLogUtils.warn(`MessageReceived handler error: {tostring(err)}`)
	end
end

function StudioBridgeConnection._dispatchRawMessage(self: StudioBridgeConnection, rawData: string)
	local decodeOk, message = pcall(HttpService.JSONDecode, HttpService, rawData)
	if not decodeOk or type(message) ~= "table" or type(message.type) ~= "string" then
		StudioBridgeLogUtils.warn(`Failed to decode message: {string.sub(tostring(rawData), 1, 200)}`)
		return
	end

	StudioBridgeLogUtils.logVerbose(
		`Received: {message.type} (requestId={string.sub(tostring(message.requestId), 1, 8)}...)`
	)

	if message.type == "shutdown" then
		self:_close()
		return
	end

	local response = self._router:Dispatch(message)
	if not response then
		StudioBridgeLogUtils.logVerbose(`No response for: {message.type}`)
		return
	end

	local encoded = self:_encode(response)
	StudioBridgeLogUtils.logVerbose(`Sending: {response.type} ({#encoded} bytes)`)
	self._webSocket:Send(encoded)
end

--[[
	Encodes `message`, or a RESULT_TOO_LARGE error for its request when it is
	over the limit.
]]
function StudioBridgeConnection._encode(self: StudioBridgeConnection, message: { [string]: any }): string
	local encoded = HttpService:JSONEncode(message)
	if #encoded <= self._maxMessageBytes or message.requestId == nil then
		return encoded
	end

	local megabytes = function(bytes: number): string
		return string.format("%.1f MB", bytes / (1024 * 1024))
	end
	return HttpService:JSONEncode({
		type = "error",
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = {
			code = "RESULT_TOO_LARGE",
			message = `The {message.type} reply is {megabytes(#encoded)}, over the {megabytes(self._maxMessageBytes)} a reply can carry. Return less, or narrow the request.`,
		},
	})
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
	StudioBridgeLogUtils.setVerbose(false)

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
