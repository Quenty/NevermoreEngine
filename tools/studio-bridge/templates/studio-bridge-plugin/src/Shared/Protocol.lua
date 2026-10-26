--!strict
--[=[
	Encodes and decodes studio-bridge wire protocol messages.

	Every message is an envelope of `{ type, sessionId, payload, requestId? }`.

	Uses Lune's serde for JSON, so this only loads under Lune; the plugin itself
	goes through HttpService and never requires it.

	@class Protocol
]=]

local serde = (require :: any)("@lune/serde")

local Protocol = {}

export type Message = {
	type: string,
	sessionId: string,
	payload: { [string]: any },
	requestId: string?,
}

local KNOWN_TYPES: { [string]: boolean } = {
	-- Plugin -> Server
	register = true,
	scriptComplete = true,
	stateResult = true,
	screenshotResult = true,
	dataModelResult = true,
	logsResult = true,
	stateChange = true,
	heartbeat = true,
	subscribeResult = true,
	unsubscribeResult = true,

	-- Server -> Plugin
	execute = true,
	shutdown = true,
	queryState = true,
	captureScreenshot = true,
	queryDataModel = true,
	queryLogs = true,
	subscribe = true,
	unsubscribe = true,

	-- Bidirectional
	error = true,
}

--[=[
	Encodes a message to JSON, leaving `requestId` out when it is nil.
]=]
function Protocol.encode(message: Message): string
	local envelope: { [string]: any } = {
		type = message.type,
		sessionId = message.sessionId,
		payload = message.payload,
	}

	if message.requestId ~= nil then
		envelope.requestId = message.requestId
	end

	return serde.encode("json", envelope)
end

--[=[
	Decodes and validates a JSON message. Returns the message, or nil and the
	reason it was rejected.
]=]
function Protocol.decode(raw: string): (Message?, string?)
	local ok, parsed = pcall(serde.decode, "json", raw)
	if not ok then
		return nil, `invalid JSON: {tostring(parsed)}`
	end

	if type(parsed) ~= "table" then
		return nil, `expected JSON object, got {type(parsed)}`
	end

	if type(parsed.type) ~= "string" then
		return nil, "missing or invalid field: type"
	end

	if type(parsed.sessionId) ~= "string" then
		return nil, "missing or invalid field: sessionId"
	end

	if type(parsed.payload) ~= "table" then
		return nil, "missing or invalid field: payload"
	end

	if not KNOWN_TYPES[parsed.type] then
		return nil, `unknown message type: {parsed.type}`
	end

	return {
		type = parsed.type,
		sessionId = parsed.sessionId,
		payload = parsed.payload,
		requestId = if type(parsed.requestId) == "string" then parsed.requestId else nil,
	},
		nil
end

return Protocol
