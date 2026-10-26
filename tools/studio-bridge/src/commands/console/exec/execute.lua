--!strict
--[=[
	Action that compiles and runs Luau code sent by the bridge, answering with a
	`scriptComplete` message.

	- Echoes the request's `requestId` on every response.
	- Fails with `SCRIPT_LOAD_ERROR` when the code does not compile and
	  `SCRIPT_RUNTIME_ERROR` when it throws.
	- Runs concurrent requests one at a time, in arrival order.
	- Marshals everything the script returns onto `payload.returnValues`, so a
	  caller reads a result as a value instead of scraping it out of the output.

	Loaded standalone inside the plugin, so it cannot require anything. Has no
	Roblox dependencies and also loads under Lune.

	@class ExecuteAction
]=]

local MAX_DEPTH = 64

local ExecuteAction = {}

type SendMessage = (message: { [string]: any }) -> ()

type QueuedRequest = {
	payload: { [string]: any },
	requestId: string?,
	sessionId: string,
	sendMessage: SendMessage?,
}

type LogEntry = {
	level: string,
	body: string,
	timestamp: number,
}

local queue: { QueuedRequest } = {}
local isProcessing = false

--[=[
	Registers the `execute` handler. With `sendMessage`, requests queue and each
	reply is sent directly; without it, the reply goes back through the router.
]=]
function ExecuteAction.register(router: any, sendMessage: SendMessage?)
	router:setResponseType("execute", "scriptComplete")
	router:register("execute", function(payload: { [string]: any }, requestId: string, sessionId: string)
		if not sendMessage then
			return ExecuteAction._handleExecute(payload, requestId, sessionId, nil)
		end

		table.insert(queue, {
			payload = payload,
			requestId = requestId,
			sessionId = sessionId,
			sendMessage = sendMessage,
		})
		ExecuteAction._processQueue()

		-- Replied through sendMessage, so the router must not reply as well
		return nil
	end)
end

--[=[
	Cancels every queued request, replying `ACTION_REPLACED` to each.
]=]
function ExecuteAction.teardown()
	for _, request in queue do
		if request.sendMessage then
			request.sendMessage({
				type = "scriptComplete",
				sessionId = request.sessionId,
				requestId = request.requestId,
				payload = {
					success = false,
					error = "Action re-registered, request cancelled",
					code = "ACTION_REPLACED",
				},
			})
		end
	end

	ExecuteAction._resetQueue()
end

--[=[
	Runs an execute request and returns its response payload, bypassing the queue.
]=]
function ExecuteAction.handleExecute(
	payload: { [string]: any },
	requestId: string?,
	sessionId: string
): { [string]: any }?
	return ExecuteAction._handleExecute(payload, requestId, sessionId, nil)
end

function ExecuteAction._resetQueue()
	queue = {}
	isProcessing = false
end

function ExecuteAction._processQueue()
	if isProcessing then
		return
	end
	isProcessing = true

	while #queue > 0 do
		local request = table.remove(queue, 1) :: QueuedRequest
		ExecuteAction._handleExecute(request.payload, request.requestId, request.sessionId, request.sendMessage)
	end

	isProcessing = false
end

function ExecuteAction._handleExecute(
	payload: { [string]: any },
	requestId: string?,
	sessionId: string,
	sendMessage: SendMessage?
): { [string]: any }?
	-- An empty requestId means none was sent
	local effectiveRequestId = if requestId ~= "" then requestId else nil

	local function reply(responsePayload: { [string]: any }): { [string]: any }?
		if not sendMessage then
			return responsePayload
		end

		sendMessage({
			type = "scriptComplete",
			sessionId = sessionId,
			requestId = effectiveRequestId,
			payload = responsePayload,
		})
		return nil
	end

	local code = payload and (payload.script or payload.code)
	if type(code) ~= "string" then
		return reply({ success = false, error = "Missing code in execute request", code = "SCRIPT_LOAD_ERROR" })
	end

	local compileOk, fn, compileErr = pcall(loadstring :: any, code)
	if not compileOk then
		return reply({ success = false, error = tostring(fn), code = "SCRIPT_LOAD_ERROR" })
	end
	if not fn then
		return reply({
			success = false,
			error = if compileErr then tostring(compileErr) else "Failed to compile script",
			code = "SCRIPT_LOAD_ERROR",
		})
	end

	-- loadstring'd code reads print/warn from its global environment, so
	-- shadowing them with locals here would capture nothing
	local captured: { LogEntry } = {}
	local env = getfenv(fn)
	local originalPrint = env.print
	local originalWarn = env.warn

	env.print = function(...)
		table.insert(captured, ExecuteAction._createLogEntry("Print", ...))
		originalPrint(...)
	end
	env.warn = function(...)
		table.insert(captured, ExecuteAction._createLogEntry("Warning", ...))
		originalWarn(...)
	end

	local returned = table.pack(pcall(fn))

	env.print = originalPrint
	env.warn = originalWarn

	if not returned[1] then
		return reply({
			success = false,
			error = tostring(returned[2]),
			code = "SCRIPT_RUNTIME_ERROR",
			output = captured,
		})
	end

	return reply({
		success = true,
		output = captured,
		returnValues = ExecuteAction._serializeReturnValues(returned),
	})
end

function ExecuteAction._createLogEntry(level: string, ...: any): LogEntry
	local parts = table.create(select("#", ...))
	for index = 1, select("#", ...) do
		parts[index] = tostring((select(index, ...)))
	end

	return {
		level = level,
		body = table.concat(parts, "\t"),
		timestamp = os.clock(),
	}
end

--[[
	Marshals what a script returned, in order, skipping the pcall status. A nil
	becomes an explicit marker: a JSON array cannot hold a hole, and dropping it
	would shift every later value into the wrong position.
]]
function ExecuteAction._serializeReturnValues(packed: { n: number, [number]: any }): { any }
	local returnValues = {}
	for index = 2, packed.n do
		local serialized = ExecuteAction._serializeValue(packed[index], 1, {})
		if serialized == nil then
			serialized = { type = "Nil" }
		end
		returnValues[index - 1] = serialized
	end
	return returnValues
end

--[[
	Produces the SerializedReturnValue shapes declared in web-socket-protocol.ts.
	Duplicates the marshaller in query-data-model.lua, since actions cannot
	require each other.
]]
function ExecuteAction._serializeValue(value: any, depth: number, seen: { [any]: boolean }): any
	local valueType = typeof(value)

	if valueType == "nil" or valueType == "string" or valueType == "boolean" then
		return value
	elseif valueType == "number" then
		-- inf and nan have no JSON spelling, and encoding one produces a
		-- document the server cannot decode, losing the entire message
		if value ~= value or value == math.huge or value == -math.huge then
			return ExecuteAction._unsupported("number", tostring(value))
		end
		return value
	elseif valueType == "table" then
		if depth > MAX_DEPTH then
			return ExecuteAction._unsupported("table", "<max depth exceeded>")
		end
		if seen[value] then
			return ExecuteAction._unsupported("table", "<cycle>")
		end

		seen[value] = true
		local serialized = ExecuteAction._serializeTable(value, depth, seen)
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
		return ExecuteAction._unsupported(valueType, tostring(value))
	end
end

--[[
	An array-like table becomes a JSON array, anything else a JSON object with
	string keys. Mixed tables take the object branch on purpose: JSONEncode
	rejects them, and a rejected encode drops the whole scriptComplete message.
]]
function ExecuteAction._serializeTable(value: { [any]: any }, depth: number, seen: { [any]: boolean }): any
	local count = 0
	for _ in value do
		count += 1
	end

	if count == #value then
		local array = {}
		for index = 1, count do
			array[index] = ExecuteAction._serializeValue(value[index], depth + 1, seen)
		end
		return array
	end

	local map: { [string]: any } = {}
	for key, item in value do
		map[if type(key) == "string" then key else tostring(key)] = ExecuteAction._serializeValue(item, depth + 1, seen)
	end
	return map
end

function ExecuteAction._unsupported(typeName: string, text: string): { [string]: any }
	return { type = "Unsupported", typeName = typeName, toString = text }
end

return ExecuteAction
