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

	local success, runtimeError = pcall(fn)

	-- Restore originals
	env.print = originalPrint
	env.warn = originalWarn

	if not success then
		return sendResult({ success = false, error = tostring(runtimeError), code = "SCRIPT_RUNTIME_ERROR", output = captured })
	end

	return sendResult({ success = true, output = captured })
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
