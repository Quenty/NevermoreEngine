--!strict
--[=[
	Runs a `playtest run` script inside the playtest's server and ends the
	playtest with the result, so running a script does not depend on Studio
	loading user plugins into playtests.

	The `run-playtest-script` action plants this source as a Script in the edit
	DataModel, with the code as a ModuleScript named `Code` under it, and starts a
	playtest. The playtest copies the edit DataModel, so the runner starts in its
	server. It only acts in the playtest it was planted for: anywhere else, such
	as a place saved while it was planted, it does nothing.

	The result crosses back through `StudioTestService:EndTest` in the same shape
	as an `execute` reply. Instances cannot cross DataModels, so values are
	marshalled here. Output capture, tracebacks and the marshaller are copies of
	execute.lua's, since the runner cannot require it.

	@class PlaytestRunner
]=]

local MAX_DEPTH = 64
local PLUGIN_PREFIX = "[StudioBridge]"
-- Tracebacks name this module's frames the way its first line does
local OWN_FRAME_PREFIX = string.match(debug.traceback(), "^([^\n]-):%d+")

local PlaytestRunner = {}

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

--[=[
	Runs the `Code` module under `runner` and ends the playtest with the result,
	when this playtest is the one `runner` was planted for.
]=]
function PlaytestRunner.runAsync(runner: Instance, studioTestService: any, players: Players)
	local argsOk, testArgs = pcall(function()
		return studioTestService:GetTestArgs()
	end)
	if not argsOk or type(testArgs) ~= "table" or testArgs.studioBridgeRunnerId ~= runner:GetAttribute("RunnerId") then
		return
	end

	local hasEnded = false
	local captured: { LogEntry } = {}
	local function endTest(result: { [string]: any })
		if hasEnded then
			return
		end
		hasEnded = true
		studioTestService:EndTest(result)
	end

	local timeoutSec = testArgs.studioBridgeTimeoutSec
	if type(timeoutSec) == "number" then
		task.delay(timeoutSec, function()
			endTest({
				success = false,
				error = `Script timed out after {timeoutSec}s`,
				code = "SCRIPT_TIMEOUT",
				output = captured,
			})
		end)
	end

	-- The plugin path waits for the client to connect, so match it in play mode
	if testArgs.studioBridgeWaitForPlayer and #players:GetPlayers() == 0 then
		players.PlayerAdded:Wait()
	end

	local scriptArgs = if type(testArgs.studioBridgeScriptArgs) == "table" then testArgs.studioBridgeScriptArgs else {}
	endTest(PlaytestRunner.run(runner:FindFirstChild("Code"), captured, scriptArgs))
end

--[=[
	Runs a code module with `args`, collecting everything logged while it runs
	into `captured`, and returns the result in the shape of an `execute` reply.
]=]
function PlaytestRunner.run(codeModule: Instance?, captured: { LogEntry }, args: { any }?): { [string]: any }
	if not (codeModule and codeModule:IsA("ModuleScript")) then
		return { success = false, error = "Runner has no Code module", code = "SCRIPT_LOAD_ERROR", output = captured }
	end

	local requireOk, fn = pcall(require, codeModule)
	if not requireOk or type(fn) ~= "function" then
		return {
			success = false,
			error = if requireOk then "Code module did not return a function" else tostring(fn),
			code = "SCRIPT_LOAD_ERROR",
			output = captured,
		}
	end

	local logConnection = PlaytestRunner._captureOutput(captured)
	local returned = table.pack(xpcall(fn, function(err)
		return {
			message = tostring(err),
			traceback = PlaytestRunner._dropOwnFrames(debug.traceback(nil, 2)),
		}
	end, table.unpack(args or {})))

	-- MessageOut can fire a frame late, after the code's last print
	task.wait()
	logConnection:Disconnect()

	if not returned[1] then
		return {
			success = false,
			error = returned[2].message,
			traceback = returned[2].traceback,
			code = "SCRIPT_RUNTIME_ERROR",
			output = captured,
		}
	end

	return {
		success = true,
		output = captured,
		returnValues = PlaytestRunner._serializeReturnValues(returned),
	}
end

--[[
	Drops the frames of this module's own wrapper from a traceback, leaving only
	the script's.
]]
function PlaytestRunner._dropOwnFrames(traceback: string): string
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
	Collects every message logged until the connection is disconnected, other
	than the plugin's own.
]]
function PlaytestRunner._captureOutput(captured: { LogEntry }): RBXScriptConnection
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
	Marshals what a script returned, in order, skipping the pcall status. A nil
	becomes an explicit marker, since an array cannot hold a hole.
]]
function PlaytestRunner._serializeReturnValues(packed: { n: number, [number]: any }): { any }
	local returnValues = {}
	for index = 2, packed.n do
		local serialized = PlaytestRunner._serializeValue(packed[index], 1, {})
		if serialized == nil then
			serialized = { type = "Nil" }
		end
		returnValues[index - 1] = serialized
	end
	return returnValues
end

--[[
	Produces the SerializedReturnValue shapes declared in web-socket-protocol.ts.
	Copied from execute.lua; keep the two in step.
]]
function PlaytestRunner._serializeValue(value: any, depth: number, seen: { [any]: boolean }): any
	local valueType = typeof(value)

	if valueType == "nil" or valueType == "string" or valueType == "boolean" then
		return value
	elseif valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return PlaytestRunner._unsupported("number", tostring(value))
		end
		return value
	elseif valueType == "table" then
		if depth > MAX_DEPTH then
			return PlaytestRunner._unsupported("table", "<max depth exceeded>")
		end
		if seen[value] then
			return PlaytestRunner._unsupported("table", "<cycle>")
		end

		seen[value] = true
		local serialized = PlaytestRunner._serializeTable(value, depth, seen)
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
		return PlaytestRunner._unsupported(valueType, tostring(value))
	end
end

function PlaytestRunner._serializeTable(value: { [any]: any }, depth: number, seen: { [any]: boolean }): any
	local count = 0
	for _ in value do
		count += 1
	end

	if count == #value then
		local array = {}
		for index = 1, count do
			array[index] = PlaytestRunner._serializeValue(value[index], depth + 1, seen)
		end
		return array
	end

	local map: { [string]: any } = {}
	for key, item in value do
		map[if type(key) == "string" then key else tostring(key)] =
			PlaytestRunner._serializeValue(item, depth + 1, seen)
	end
	return map
end

function PlaytestRunner._unsupported(typeName: string, text: string): { [string]: any }
	return { type = "Unsupported", typeName = typeName, toString = text }
end

-- Planted as a Script it runs; in the test place it is a ModuleScript specs require
if script:IsA("Script") then
	task.spawn(PlaytestRunner.runAsync, script, game:GetService("StudioTestService"), game:GetService("Players"))
end

return PlaytestRunner
