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
	  - Failure isolation: a request that throws while marshalling or
	    reporting its result is answered with an error rather than left to
	    latch the queue for the rest of the session.

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

-- The depth cap alone does not bound the work. `seen` is cleared as the walk
-- leaves a table -- correct, since a value reachable by two separate paths is
-- not a cycle -- which means a shared reference is expanded once per edge.
-- `for i = 1, 30 do x = { a = x, b = x } end` is only 30 levels deep but 2^30
-- nodes, so a total node budget is what actually keeps Studio alive.
local MAX_NODES = 100_000

type MarshalState = { seen: { [any]: boolean }, budget: number }

local function unsupported(typeName: string, text: string): { [string]: any }
	return { type = "Unsupported", typeName = typeName, toString = text }
end

local serializeValue: (value: any, depth: number, state: MarshalState) -> any

-- An array-like table becomes a JSON array, anything else a JSON object with
-- string keys. Mixed tables take the object branch on purpose: JSONEncode
-- rejects them, and a rejected encode drops the whole scriptComplete message.
--
-- Traversal is raw (`next`, `rawlen`, `rawget`) so `__iter`, `__len` and
-- `__index` cannot make a returned table report contents it does not have --
-- and cannot throw from inside the walk. A metatable is not part of the value,
-- so what gets marshalled is the table as it actually is.
local function serializeTable(value: { [any]: any }, depth: number, state: MarshalState): any
	local count = 0
	for _ in next, value do
		count += 1
	end

	if count == rawlen(value) then
		local array = {}
		for index = 1, count do
			array[index] = serializeValue(rawget(value :: any, index), depth + 1, state)
		end
		return array
	end

	local map: { [string]: any } = {}
	for key, item in next, value do
		local stringKey = if type(key) == "string" then key else tostring(key)
		if map[stringKey] ~= nil then
			-- Two distinct Luau keys collapsed onto one JSON key (`[1]` and
			-- `"1"`). Marking it keeps the loss visible rather than quietly
			-- serving whichever one the traversal happened to reach last.
			map[stringKey] = unsupported("collision", `<two keys collapsed onto "{stringKey}">`)
		else
			map[stringKey] = serializeValue(item, depth + 1, state)
		end
	end
	return map
end

function serializeValue(value: any, depth: number, state: MarshalState): any
	local valueType = typeof(value)

	state.budget -= 1
	if state.budget < 0 then
		return unsupported(valueType, "<value budget exceeded>")
	end

	if valueType == "nil" then
		-- A JSON array cannot hold a hole, and dropping the entry would shift
		-- every later value into the wrong position.
		return { type = "Nil" }
	elseif valueType == "string" or valueType == "boolean" then
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
		if state.seen[value] then
			return unsupported("table", "<cycle>")
		end
		state.seen[value] = true
		local serialized = serializeTable(value, depth, state)
		state.seen[value] = nil
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

-- Marshal the values a script returned, in order. The depth cap, cycle set and
-- node budget are shared across all of them, so one run cannot be talked into
-- unbounded work by spreading it over several return values.
local function serializeReturnValues(packed: { n: number, [number]: any }): { any }
	local state: MarshalState = { seen = {}, budget = MAX_NODES }
	local returnValues = {}
	for index = 2, packed.n do
		returnValues[index - 1] = serializeValue(packed[index], 1, state)
	end
	return returnValues
end

-- Marshalling walks values the script chose, so a hostile metatable can still
-- throw from somewhere the raw traversal cannot avoid -- a table key whose
-- `__tostring` errors, say. Degrading to a marker keeps one bad value from
-- failing the run, and keeps it from throwing out of _handleExecute, which in
-- queue mode would latch _processing and strand every later request.
local function trySerializeReturnValues(packed: { n: number, [number]: any }): { any }
	local ok, returnValues = pcall(serializeReturnValues, packed)
	if ok then
		return returnValues
	end
	return { unsupported("unknown", `<not serializable: {tostring(returnValues)}>`) }
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
		returnValues = trySerializeReturnValues(returned),
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
		-- A throw here must not escape the loop. _processing would stay latched
		-- for the rest of the Studio session, every later execute request would
		-- pile up in _queue with nothing left to drain it, and the plugin never
		-- re-registers this action on its own (syncActions sees an unchanged
		-- hash), so only restarting Studio would recover. The most likely
		-- thrower is sendMessage itself: it JSONEncodes a payload built partly
		-- out of values the script chose.
		local ok, err =
			pcall(ExecuteAction._handleExecute, item.payload, item.requestId, item.sessionId, item.sendMessage)

		if not ok and item.sendMessage then
			-- Tell the requester, or the CLI waits out its whole timeout with no
			-- idea the request was dropped. Small fixed payload, so the encode
			-- that just failed cannot fail again for the same reason -- but it
			-- is still guarded, since it is the last thing standing between a
			-- bad response and the latch above.
			local response: { [string]: any } = {
				type = "scriptComplete",
				sessionId = item.sessionId,
				payload = {
					success = false,
					error = `Failed to report script result: {tostring(err)}`,
					code = "INTERNAL_ERROR",
				},
			}
			if item.requestId ~= nil and item.requestId ~= "" then
				response.requestId = item.requestId
			end
			pcall(item.sendMessage, response)
		end
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
