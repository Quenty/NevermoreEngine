--!strict
--[=[
	Action that compiles and runs Luau code sent by the bridge, answering with a
	`scriptComplete` message.

	- Echoes the request's `requestId` on every response.
	- Fails with `SCRIPT_LOAD_ERROR` when the code does not compile,
	  `SCRIPT_RUNTIME_ERROR` with a `traceback` when it throws, and
	  `SCRIPT_TIMEOUT` when it outlives `payload.timeoutMs`. A timed out script
	  is cancelled, so the requests queued behind it still run.
	- Passes `payload.inputs`, a list of base64 files, to the script as buffers
	  in `...`, followed by `payload.args`, a list of strings.
	- Runs concurrent requests one at a time, in arrival order.
	- Returns everything printed while the script runs, read from LogService, so
	  output from required modules and from threads the script starts comes back.
	- Marshals everything the script returns onto `payload.returnValues`, so a
	  caller reads a result as a value instead of scraping it out of the output.

	Loaded standalone inside the plugin, so it cannot require anything.

	Compiles through the router's `Compile`, which still works in a playtest's
	client where `loadstring` does not exist. Routers from older plugins have no
	`Compile`, and fall back to `loadstring`.

	@class ExecuteAction
]=]

local MAX_DEPTH = 64
local CHUNK_NAME = "=exec"
local GAME_RUNNER_NAME = "StudioBridgeRunAsGame"
local GAME_RUNNER_HEADER =
	'local __bridgeArgs = table.pack(script:WaitForChild("Args"):Invoke()) local __bridgeResult = table.pack(xpcall(function(...) '
local GAME_RUNNER_FOOTER =
	'\nend, function(err) return { message = tostring(err), traceback = debug.traceback(nil, 2) } end, table.unpack(__bridgeArgs, 1, __bridgeArgs.n))) local __bridgeOut = { n = __bridgeResult.n, ok = __bridgeResult[1] } for i = 2, __bridgeResult.n do __bridgeOut["v" .. (i - 1)] = __bridgeResult[i] end script:WaitForChild("Done"):Fire(__bridgeOut)'
local NO_PLUGIN_MESSAGE =
	"This playtest session can't run plugin code, since Studio's \"Load user plugins on playtest\" setting is off. Turn the setting on, or pass --run-as mcp, which can't require the game's modules."
local NOT_RUNNING_MESSAGE =
	"--run-as game needs a running playtest. Run 'studio-bridge playtest start', then add --context server."

local MIN_OUTPUT_WAIT_FRAMES = 3
local MAX_OUTPUT_WAIT_FRAMES = 30
local PLUGIN_PREFIX = "[StudioBridge]"
-- Tracebacks name this module's frames the way its first line does
local OWN_FRAME_PREFIX = string.match(debug.traceback(), "^([^\n]-):%d+")

local ExecuteAction = {}

type SendMessage = (message: { [string]: any }) -> ()

type QueuedRequest = {
	payload: { [string]: any },
	requestId: string?,
	sessionId: string,
	sendMessage: SendMessage?,
	receivedAt: number,
}

type LogEntry = {
	level: string,
	body: string,
	timestamp: number,
}

local LOG_LEVELS: { [Enum.MessageType]: string } = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

local queue: { QueuedRequest } = {}
local isProcessing = false
local compile: (source: string, chunkName: string?) -> (any, string?) = loadstring :: any

--[=[
	Registers the `execute` handler. With `sendMessage`, requests queue and each
	reply is sent directly; without it, the reply goes back through the router.
]=]
function ExecuteAction.register(router: any, sendMessage: SendMessage?)
	if type(router.Compile) == "function" then
		compile = function(source: string, chunkName: string?)
			return router:Compile(source, chunkName)
		end
	end

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
			receivedAt = os.clock(),
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
		ExecuteAction._handleExecute(
			request.payload,
			request.requestId,
			request.sessionId,
			request.sendMessage,
			request.receivedAt
		)
	end

	isProcessing = false
end

function ExecuteAction._handleExecute(
	payload: { [string]: any },
	requestId: string?,
	sessionId: string,
	sendMessage: SendMessage?,
	receivedAt: number?
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

	local canPlant = ExecuteAction._canPlantScripts()
	if payload.runAs == "plugin" and not canPlant then
		return reply({ success = false, error = NO_PLUGIN_MESSAGE, code = "SCRIPT_LOAD_ERROR", ranAs = "game" })
	end
	local asGame = payload.runAs == "game" and canPlant
	if asGame and not game:GetService("RunService"):IsRunning() then
		return reply({ success = false, error = NOT_RUNNING_MESSAGE, code = "SCRIPT_LOAD_ERROR" })
	end
	local ranAs = if asGame or not canPlant then "game" else "plugin"

	local compileOk, fn, compileErr = pcall(compile, code, CHUNK_NAME)
	if not compileOk then
		return reply({ success = false, error = tostring(fn), code = "SCRIPT_LOAD_ERROR", ranAs = ranAs })
	end
	if not fn then
		return reply({
			success = false,
			error = if compileErr then tostring(compileErr) else "Failed to compile script",
			code = "SCRIPT_LOAD_ERROR",
			ranAs = ranAs,
		})
	end

	local args = payload.args or {}
	if type(args) ~= "table" then
		return reply({ success = false, error = "Script args must be a list", code = "SCRIPT_LOAD_ERROR" })
	end

	local inputs = payload.inputs or {}
	if type(inputs) ~= "table" then
		return reply({ success = false, error = "Script inputs must be a list", code = "SCRIPT_LOAD_ERROR" })
	end

	local scriptArgs = {}
	for index, encoded in inputs do
		local decodeOk, decoded = pcall(function()
			return game:GetService("EncodingService"):Base64Decode(buffer.fromstring(encoded))
		end)
		if not decodeOk or type(encoded) ~= "string" then
			return reply({
				success = false,
				error = `Script input {index} is not valid base64`,
				code = "SCRIPT_LOAD_ERROR",
			})
		end
		table.insert(scriptArgs, decoded)
	end
	for _, arg in args do
		table.insert(scriptArgs, arg)
	end

	local timeoutMs = payload.timeoutMs
	local timeoutSeconds = if type(timeoutMs) == "number" then timeoutMs / 1000 else nil
	-- The caller's timeout started when it sent the request, not when its turn came
	if timeoutSeconds and receivedAt then
		timeoutSeconds -= os.clock() - receivedAt
		if timeoutSeconds <= 0 then
			return reply({
				success = false,
				error = `The script waited {ExecuteAction._formatSeconds(timeoutMs)} behind other scripts and never ran. Run it again once they finish, or pass a longer --script-timeout.`,
				code = "SCRIPT_TIMEOUT",
			})
		end
	end

	local captured: { LogEntry } = {}
	local logConnection = ExecuteAction._captureOutput(captured)
	local status, result
	if asGame then
		status, result = ExecuteAction._runAsGameAsync(code, timeoutSeconds, scriptArgs)
	else
		status, result = ExecuteAction._runAsync(fn, timeoutSeconds, scriptArgs)
	end

	ExecuteAction._waitForOutputAsync(captured)
	logConnection:Disconnect()

	if status == "timeout" then
		return reply({
			success = false,
			error = `The script ran longer than {ExecuteAction._formatSeconds(timeoutMs)} and was stopped. Pass a longer --script-timeout, or make it finish sooner.`,
			code = "SCRIPT_TIMEOUT",
			output = captured,
			ranAs = ranAs,
		})
	elseif status == "error" then
		return reply({
			success = false,
			error = result.message,
			traceback = result.traceback,
			code = "SCRIPT_RUNTIME_ERROR",
			output = captured,
			ranAs = ranAs,
		})
	end

	return reply({
		success = true,
		output = captured,
		returnValues = ExecuteAction._serializeReturnValues(result),
		ranAs = ranAs,
	})
end

function ExecuteAction._formatSeconds(milliseconds: number): string
	return `{math.round(milliseconds / 100) / 10}s`
end

--[[
	Drops the frames of this module's own wrapper from a traceback, leaving only
	the script's.
]]
function ExecuteAction._dropOwnFrames(traceback: string): string
	if not OWN_FRAME_PREFIX then
		return traceback
	end

	local lines = {}
	for _, line in string.split(traceback, "\n") do
		if string.sub(line, 1, #OWN_FRAME_PREFIX + 1) ~= `{OWN_FRAME_PREFIX}:` then
			table.insert(lines, line)
		end
	end
	return table.concat(lines, "\n")
end

--[[
	Waits for the script's last output to arrive. MessageOut fires a frame or
	two after a print, more in a playtest's server, so this waits a few frames
	and then for one without new output.
]]
function ExecuteAction._waitForOutputAsync(captured: { LogEntry })
	local seen = #captured
	local frames = 0
	local grew
	repeat
		task.wait()
		frames += 1
		grew = #captured ~= seen
		seen = #captured
	until frames >= MAX_OUTPUT_WAIT_FRAMES or (frames >= MIN_OUTPUT_WAIT_FRAMES and not grew)
end

--[[
	Collects every message logged until the connection is disconnected, other
	than the plugin's own.
]]
function ExecuteAction._captureOutput(captured: { LogEntry }): RBXScriptConnection
	return game:GetService("LogService").MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		if string.sub(message, 1, #PLUGIN_PREFIX) == PLUGIN_PREFIX then
			return
		end

		table.insert(captured, {
			level = LOG_LEVELS[messageType] or "Print",
			body = message,
			timestamp = os.clock(),
		})
	end)
end

--[[
	Runs `fn` with `args` in its own thread. Returns "ok" and everything it returned
	(pcall-style, status first), "error" and its message and traceback, or
	"timeout" once `timeoutSec` passes, after cancelling the thread.
]]
function ExecuteAction._runAsync(fn: (...any) -> ...any, timeoutSec: number?, args: { any }?): (string, any)
	local callerThread = coroutine.running()
	local isWaiting = false
	local outcome: { status: string, result: any }? = nil

	local function finish(status: string, result: any)
		if outcome then
			return
		end
		outcome = { status = status, result = result }
		if isWaiting then
			task.defer(callerThread)
		end
	end

	local scriptThread = task.spawn(function()
		local packed = table.pack(xpcall(fn, function(err)
			return {
				message = tostring(err),
				traceback = ExecuteAction._dropOwnFrames(debug.traceback(nil, 2)),
			}
		end, table.unpack(args or {})))
		if packed[1] then
			finish("ok", packed)
		else
			finish("error", packed[2])
		end
	end)

	if not outcome then
		local timeoutThread = if timeoutSec
			then task.delay(timeoutSec, function()
				if not outcome then
					pcall(task.cancel, scriptThread)
					finish("timeout", nil)
				end
			end)
			else nil

		isWaiting = true
		coroutine.yield()
		if timeoutThread then
			pcall(task.cancel, timeoutThread)
		end
	end

	local final = outcome :: { status: string, result: any }
	return final.status, final.result
end

--[[
	Whether this thread may set a script's source: a plugin can, the bridge
	planted into a playtest cannot.
]]
function ExecuteAction._canPlantScripts(): boolean
	return (pcall(function()
		local probe = Instance.new("Script")
		probe.Source = ""
		probe:Destroy()
	end))
end

--[[
	Runs `code` as an ordinary game Script (server) or LocalScript (client), so
	`require` returns the modules the running game uses rather than the plugin's
	own copies. Returns what `_runAsync` returns.
]]
function ExecuteAction._runAsGameAsync(code: string, timeoutSec: number?, args: { any }?): (string, any)
	local RunService = game:GetService("RunService")
	local isServer = RunService:IsServer()
	local runner = Instance.new(if isServer then "Script" else "LocalScript")
	runner.Name = GAME_RUNNER_NAME

	local packedArgs = args or {}
	local argsFunction = Instance.new("BindableFunction")
	argsFunction.Name = "Args"
	argsFunction.OnInvoke = function()
		return table.unpack(packedArgs)
	end
	argsFunction.Parent = runner

	local done = Instance.new("BindableEvent")
	done.Name = "Done"
	done.Parent = runner

	local outcome: { [string]: any }? = nil
	local connection = done.Event:Connect(function(result)
		outcome = result
	end)

	runner.Source = GAME_RUNNER_HEADER .. code .. GAME_RUNNER_FOOTER
	runner.Parent = if isServer
		then game:GetService("ServerScriptService")
		else (game:GetService("Players").LocalPlayer :: any):WaitForChild("PlayerScripts")

	local deadline = if timeoutSec then os.clock() + timeoutSec else math.huge
	while not outcome and os.clock() < deadline do
		task.wait()
	end
	connection:Disconnect()
	runner:Destroy()

	if not outcome then
		return "timeout", nil
	end
	local final = outcome :: { [string]: any }
	if final.ok then
		local packed = { n = final.n, true }
		for index = 2, final.n do
			packed[index] = final["v" .. (index - 1)]
		end
		return "ok", packed
	end
	local err = final.v1
	return "error",
		{
			message = if type(err) == "table" then tostring(err.message) else tostring(err),
			traceback = if type(err) == "table" then err.traceback else nil,
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
