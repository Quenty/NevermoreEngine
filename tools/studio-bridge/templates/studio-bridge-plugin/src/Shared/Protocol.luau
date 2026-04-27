--[[
	Protocol module for encoding and decoding studio-bridge wire protocol messages.

	This module is a pure serialization layer with no Roblox dependencies. It uses
	Lune's serde library for JSON and is testable outside of Studio.

	Wire protocol envelope (all messages):
	  { type: string, sessionId: string, payload: object }

	Extended fields (optional):
	  { requestId?: string, protocolVersion?: number }
]]

local serde = require("@lune/serde")

local Protocol = {}

-- ---------------------------------------------------------------------------
-- Known message types
-- ---------------------------------------------------------------------------

local KNOWN_TYPES: { [string]: boolean } = {
	-- Plugin -> Server (v1)
	hello = true,
	output = true,
	scriptComplete = true,

	-- Plugin -> Server (v2)
	register = true,
	stateResult = true,
	screenshotResult = true,
	dataModelResult = true,
	logsResult = true,
	stateChange = true,
	heartbeat = true,
	subscribeResult = true,
	unsubscribeResult = true,

	-- Server -> Plugin (v1)
	welcome = true,
	execute = true,
	shutdown = true,

	-- Server -> Plugin (v2)
	queryState = true,
	captureScreenshot = true,
	queryDataModel = true,
	queryLogs = true,
	subscribe = true,
	unsubscribe = true,

	-- Bidirectional (v2)
	error = true,
}

-- ---------------------------------------------------------------------------
-- encode
-- ---------------------------------------------------------------------------

--[[
	Encode a message table to a JSON string.

	@param message - Table with required fields: type, sessionId, payload.
	                 Optional fields: requestId, protocolVersion.
	@return JSON string representation of the message.
]]
function Protocol.encode(message: {
	type: string,
	sessionId: string,
	payload: { [string]: any },
	requestId: string?,
	protocolVersion: number?,
}): string
	local envelope: { [string]: any } = {
		type = message.type,
		sessionId = message.sessionId,
		payload = message.payload,
	}

	if message.requestId ~= nil then
		envelope.requestId = message.requestId
	end

	if message.protocolVersion ~= nil then
		envelope.protocolVersion = message.protocolVersion
	end

	return serde.encode("json", envelope)
end

-- ---------------------------------------------------------------------------
-- decode
-- ---------------------------------------------------------------------------

--[[
	Decode a JSON string to a message table.

	@param raw - JSON string to decode.
	@return (message, nil) on success; (nil, errorString) on failure.
]]
function Protocol.decode(raw: string): ({ [string]: any }?, string?)
	local ok, parsed = pcall(serde.decode, "json" :: any, raw)
	if not ok then
		return nil, "invalid JSON: " .. tostring(parsed)
	end

	if type(parsed) ~= "table" then
		return nil, "expected JSON object, got " .. type(parsed)
	end

	-- Validate required fields
	if type(parsed.type) ~= "string" then
		return nil, "missing or invalid field: type"
	end

	if type(parsed.sessionId) ~= "string" then
		return nil, "missing or invalid field: sessionId"
	end

	if type(parsed.payload) ~= "table" then
		return nil, "missing or invalid field: payload"
	end

	-- Validate known message type
	if not KNOWN_TYPES[parsed.type] then
		return nil, "unknown message type: " .. parsed.type
	end

	-- Build result with required fields
	local result: { [string]: any } = {
		type = parsed.type,
		sessionId = parsed.sessionId,
		payload = parsed.payload,
	}

	-- Pass through optional fields when present
	if type(parsed.requestId) == "string" then
		result.requestId = parsed.requestId
	end

	if type(parsed.protocolVersion) == "number" then
		result.protocolVersion = parsed.protocolVersion
	end

	return result, nil
end

return Protocol
