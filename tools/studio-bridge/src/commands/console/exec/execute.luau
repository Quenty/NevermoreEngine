--[[
	Execute action handler for the studio-bridge plugin.

	Compiles and runs Luau code received from the server, returning a
	scriptComplete response on success or an error response on failure.

	Supports:
	  - requestId correlation: if present in the request, echoed in all
	    response messages (scriptComplete and output).
	  - Distinct error codes: SCRIPT_LOAD_ERROR, SCRIPT_RUNTIME_ERROR.
	  - Sequential queueing: concurrent execute requests are processed
	    one at a time in FIFO order.
	  - Return values: everything the script returns is marshalled onto
	    `payload.returnValues`, so a caller can read a result as a value
	    instead of scraping it back out of printed output.

	This module has no Roblox dependencies and is testable under Lune.
]]

local ExecuteAction = {}

-- ---------------------------------------------------------------------------
-- Internal queue for sequential execution
-- ---------------------------------------------------------------------------

local _queue: { { payload: { [string]: any }, requestId: string?, sessionId: string, sendMessage: ((msg: { [string]: any }) -> ())? } } =
	{}
local _processing = false

-- ---------------------------------------------------------------------------
-- Return value serialization
-- ---------------------------------------------------------------------------

-- Produces the SerializedReturnValue shapes declared in
-- web-socket-protocol.ts. Action modules are loadstring'd standalone inside
-- the plugin and cannot require anything, so this cannot be shared with the
-- equivalent marshaller in query-data-model.luau.

local MAX_DEPTH = 64

local function unsupported(typeName: string, text: string): { [string]: any }
	return { type = "Unsupported", typeName = typeName, toString = text }
end

local serializeValue: (value: any, depth: number, seen: { [any]: boolean }) -> any

-- An array-like table becomes a JSON array, anything else a JSON object with
-- string keys. Mixed tables take the object branch on purpose: JSONEncode
-- rejects them, and a rejected encode drops the whole scriptComplete message.
local function serializeTable(value: { [any]: any }, depth: number, seen: { [any]: boolean }): any
	local count = 0
	for _ in value do
		count += 1
	end

	if count == #value then
		local array = {}
		for index = 1, count do
			array[index] = serializeValue(value[index], depth + 1, seen)
		end
		return array
	end

	local map: { [string]: any } = {}
	for key, item in value do
		map[if type(key) == "string" then key else tostring(key)] = serializeValue(item, depth + 1, seen)
	end
	return map
end

function serializeValue(value: any, depth: number, seen: { [any]: boolean }): any
	local valueType = typeof(value)

	if valueType == "nil" or valueType == "string" or valueType == "boolean" then
		return value
	elseif valueType == "number" then
		-- inf and nan have no JSON spelling, and encoding one produces a
		-- document the server cannot decode -- losing the entire message.
		if value ~= value or value == math.huge or value == -math.huge then
			return unsupported("number", tostring(value))
		end
		return value
	elseif valueType == "table" then
		if depth > MAX_DEPTH then
			return unsupported("table", "<max depth exceeded>")
		end
		if seen[value] then
			return unsupported("table", "<cycle>")
		end
		seen[value] = true
		local serialized = serializeTable(value, depth, seen)
		seen[value] = nil
		return serialized
	elseif valueType == "Vector3" then
		return { type = "Vector3", value = { value.X, value.Y, value.Z } }
	elseif valueType == "Vector2" then
		return { type = "Vector2", value = { value.X, value.Y } }
	elseif valueType == "CFrame" then
		return { type = "CFrame", value = { value:GetComponents() } }
	elseif valueType == "Color3" then
		return { type = "Color3", value = { value.R, value.G, value.B } }
	elseif valueType == "UDim2" then
		return { type = "UDim2", value = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } }
	elseif valueType == "UDim" then
		return { type = "UDim", value = { value.Scale, value.Offset } }
	elseif valueType == "BrickColor" then
		return { type = "BrickColor", name = value.Name, value = value.Number }
	elseif valueType == "EnumItem" then
		return { type = "EnumItem", enum = tostring(value.EnumType), name = value.Name, value = value.Value }
	elseif valueType == "Instance" then
		return { type = "Instance", className = value.ClassName, path = value:GetFullName() }
	else
		return unsupported(valueType, tostring(value))
	end
end

-- Marshal the values a script returned, in order. A returned nil becomes an
-- explicit marker: a JSON array cannot hold a hole, and dropping the entry
-- would shift every later value into the wrong position.
local function serializeReturnValues(packed: { n: number, [number]: any }): { any }
	local returnValues = {}
	for index = 2, packed.n do
		local serialized = serializeValue(packed[index], 1, {})
		if serialized == nil then
			serialized = { type = "Nil" }
		end
		returnValues[index - 1] = serialized
	end
	return returnValues
end

-- ---------------------------------------------------------------------------
-- Core execution logic
-- ---------------------------------------------------------------------------

-- Handle an execute request by compiling and running the provided code.
-- Captures print/warn output by temporarily intercepting the globals.
function ExecuteAction._handleExecute(
	payload: { [string]: any },
	requestId: string?,
	sessionId: string,
	sendMessage: ((msg: { [string]: any }) -> ())?
): { [string]: any }?
	local code = payload and (payload.script or payload.code)

	-- Normalize requestId: treat empty string as absent (v1 compatibility)
	local effectiveRequestId: string? = nil
	if requestId ~= nil and requestId ~= "" then
		effectiveRequestId = requestId
	end

	-- Helper to build response messages with optional requestId
	local function buildResponse(responsePayload: { [string]: any }): { [string]: any }
		local msg: { [string]: any } = {
			type = "scriptComplete",
			sessionId = sessionId,
			payload = responsePayload,
		}
		if effectiveRequestId then
			msg.requestId = effectiveRequestId
		end
		return msg
	end

	-- Helper to send or return the result
	local function sendResult(responsePayload: { [string]: any }): { [string]: any }?
		if sendMessage then
			sendMessage(buildResponse(responsePayload))
			return nil
		end
		return responsePayload
	end

	if not code or type(code) ~= "string" then
		return sendResult({ success = false, error = "Missing code in execute request", code = "SCRIPT_LOAD_ERROR" })
	end

	local compileOk, fnOrErr = pcall(loadstring, code)
	if not compileOk then
		return sendResult({ success = false, error = tostring(fnOrErr), code = "SCRIPT_LOAD_ERROR" })
	end
	if not fnOrErr then
		return sendResult({ success = false, error = "Failed to compile script", code = "SCRIPT_LOAD_ERROR" })
	end

	local fn = fnOrErr

	-- Capture output by temporarily intercepting print/warn in the global
	-- environment. Local variable shadowing doesn't work because loadstring'd
	-- code accesses the global environment, not this module's locals.
	local captured: { { level: string, body: string, timestamp: number } } = {}
	local env = getfenv(fn)
	local originalPrint = env.print
	local originalWarn = env.warn

	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		local body = table.concat(parts, "\t")
		table.insert(captured, { level = "Print", body = body, timestamp = os.clock() })
		originalPrint(...)
	end

	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		local body = table.concat(parts, "\t")
		table.insert(captured, { level = "Warning", body = body, timestamp = os.clock() })
		originalWarn(...)
	end

	local returned = table.pack(pcall(fn))
	local success = returned[1]

	-- Restore originals
	env.print = originalPrint
	env.warn = originalWarn

	if not success then
		return sendResult({
			success = false,
			error = tostring(returned[2]),
			code = "SCRIPT_RUNTIME_ERROR",
			output = captured,
		})
	end

	return sendResult({
		success = true,
		output = captured,
		returnValues = serializeReturnValues(returned),
	})
end

-- ---------------------------------------------------------------------------
-- Queue processing
-- ---------------------------------------------------------------------------

local function _processQueue()
	if _processing then
		return
	end
	_processing = true

	while #_queue > 0 do
		local item = table.remove(_queue, 1)
		ExecuteAction._handleExecute(item.payload, item.requestId, item.sessionId, item.sendMessage)
	end

	_processing = false
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- Register this handler with the ActionRouter.
function ExecuteAction.register(router: any, sendMessage: ((msg: { [string]: any }) -> ())?)
	router:setResponseType("execute", "scriptComplete")
	router:register("execute", function(payload: { [string]: any }, requestId: string, sessionId: string)
		if sendMessage then
			-- Queue the request for sequential processing
			table.insert(_queue, {
				payload = payload,
				requestId = requestId,
				sessionId = sessionId,
				sendMessage = sendMessage,
			})
			_processQueue()
			-- Return nil so the ActionRouter does not generate a response
			return nil
		else
			-- Direct mode (no sendMessage): return payload for ActionRouter wrapping
			return ExecuteAction._handleExecute(payload, requestId, sessionId, nil)
		end
	end)
end

-- Handle an execute request directly (for testing without ActionRouter).
function ExecuteAction.handleExecute(
	payload: { [string]: any },
	requestId: string?,
	sessionId: string
): { [string]: any }?
	return ExecuteAction._handleExecute(payload, requestId, sessionId, nil)
end

-- Reset the internal queue state (for testing).
function ExecuteAction._resetQueue()
	_queue = {}
	_processing = false
end

function ExecuteAction.teardown()
	for _, item in _queue do
		if item.sendMessage then
			item.sendMessage({
				type = "scriptComplete",
				sessionId = item.sessionId,
				requestId = item.requestId,
				payload = {
					success = false,
					error = "Action re-registered, request cancelled",
					code = "ACTION_REPLACED",
				},
			})
		end
	end
	_queue = {}
	_processing = false
end

return ExecuteAction
