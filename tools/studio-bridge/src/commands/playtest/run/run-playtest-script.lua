--!strict
--[=[
	Action that runs a script in a fresh playtest's server and answers with
	`scriptComplete`, the same reply as `execute`.

	It does not need the playtest's own plugin sessions, so it works whether or
	not Studio loads user plugins into playtests.

	- Compiles the code first, so a syntax error fails here without starting a
	  playtest.
	- Plants the runner source the bridge sends as a Script in
	  ServerScriptService, with the code as a ModuleScript named `Code` under it.
	  The playtest copies the edit DataModel, so the runner starts in its server,
	  runs the code and ends the playtest with the result.
	- Removes the runner from the edit DataModel once the playtest ends.

	Request: `{ type: "runPlaytestScript", payload: { mode: "play" | "run", script, runnerSource, timeoutSec, args? } }`
	Response: `{ type: "scriptComplete", payload: { success, output, returnValues?, error?, code? } }`

	@class RunPlaytestScriptAction
]=]

local RunPlaytestScriptAction = {}

type SendMessage = (message: { [string]: any }) -> ()

--[=[
	Registers the `runPlaytestScript` handler. The reply waits for the playtest to
	end, so it needs `sendMessage`.
]=]
function RunPlaytestScriptAction.register(router: any, sendMessage: SendMessage?)
	router:setResponseType("runPlaytestScript", "scriptComplete")
	router:register(
		"runPlaytestScript",
		function(payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
			local mode = payload.mode
			if mode ~= "play" and mode ~= "run" then
				error(`Unknown playtest mode: {tostring(mode)}`)
			end

			local code = payload.script
			local runnerSource = payload.runnerSource
			local timeoutSec = payload.timeoutSec
			if type(code) ~= "string" or type(runnerSource) ~= "string" or type(timeoutSec) ~= "number" then
				error("Missing script, runnerSource or timeoutSec in runPlaytestScript request")
			end

			local compileErr = RunPlaytestScriptAction._getCompileError(router, code)
			if compileErr then
				return { success = false, error = compileErr, code = "SCRIPT_LOAD_ERROR", output = {} }
			end

			if not sendMessage then
				error("Running a playtest script requires a sendMessage callback")
			end

			task.spawn(function()
				local result = RunPlaytestScriptAction._runAsync(mode, code, runnerSource, timeoutSec, payload.args)
				sendMessage({
					type = "scriptComplete",
					sessionId = sessionId,
					requestId = if requestId ~= "" then requestId else nil,
					payload = result,
				})
			end)

			-- Replied through sendMessage, so the router must not reply as well
			return nil
		end
	)
end

--[[
	Returns why the code does not compile, or nil when it does. Routers from
	older plugins have no Compile, and the edit DataModel always has loadstring.
]]
function RunPlaytestScriptAction._getCompileError(router: any, code: string): string?
	local fn, compileErr
	if type(router.Compile) == "function" then
		fn, compileErr = router:Compile(code)
	else
		fn, compileErr = (loadstring :: any)(code)
	end

	if fn then
		return nil
	end
	return if compileErr then tostring(compileErr) else "Failed to compile script"
end

function RunPlaytestScriptAction._runAsync(
	mode: string,
	code: string,
	runnerSource: string,
	timeoutSec: number,
	args: { string }?
): { [string]: any }
	local runnerId = game:GetService("HttpService"):GenerateGUID(false)

	local runner = Instance.new("Script")
	runner.Name = "StudioBridgePlaytestRunner"
	runner.Source = runnerSource
	runner:SetAttribute("RunnerId", runnerId)

	local codeModule = Instance.new("ModuleScript")
	codeModule.Name = "Code"
	-- Wrapping on the first line keeps a top-level `return` legal and line numbers unchanged
	codeModule.Source = `return function(...) {code}\nend`
	codeModule.Parent = runner

	runner.Parent = game:GetService("ServerScriptService")

	local ok, result = pcall(function()
		local studioTestService = game:GetService("StudioTestService") :: any
		local testArgs = {
			studioBridgeRunnerId = runnerId,
			studioBridgeTimeoutSec = timeoutSec,
			studioBridgeScriptArgs = args,
			studioBridgeWaitForPlayer = mode == "play",
		}
		if mode == "play" then
			return studioTestService:ExecutePlayModeAsync(testArgs)
		else
			return studioTestService:ExecuteRunModeAsync(testArgs)
		end
	end)

	runner:Destroy()

	if not ok then
		return { success = false, error = `Playtest failed to start: {result}`, output = {} }
	end
	if type(result) ~= "table" then
		return { success = false, error = "Playtest was stopped before the script finished", output = {} }
	end
	return result
end

return RunPlaytestScriptAction
