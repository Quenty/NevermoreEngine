--!strict
--[=[
	@class NevermoreTestRunnerUtils

	Unified test runner utilities for Nevermore packages.
	Handles both smoke tests (game boot) and Jest unit tests.

	- If a jest.config is found under the given root, runs Jest tests
	- If no jest.config is found, boot success is the test (smoke test)
	- Detects Open Cloud execution via OpenCloudService to control behavior
]=]

local require = require(script.Parent.loader).load(script)

local Jest = (require :: any)("Jest")

local NevermoreTestRunnerUtils = {}

--[=[
	Returns true if running inside an Open Cloud Luau Execution context.
]=]
function NevermoreTestRunnerUtils.isOpenCloud(): boolean
	local success, _ = pcall(function()
		return game:GetService("OpenCloudService")
	end)

	return success
end

--[=[
	Runs Jest tests if a jest.config is found under root. Otherwise treats
	boot success as the test (smoke test).

	In Open Cloud, errors propagate naturally and the session terminates.
	Outside Open Cloud (e.g. run-in-roblox), we call ProcessService:ExitAsync()
	so Studio exits with the correct code.

	@param root -- The instance to scan for jest.config (e.g. the package folder in ServerScriptService)
]=]
function NevermoreTestRunnerUtils.runTestsIfNeededAsync(root: Instance)
	assert(typeof(root) == "Instance", "Bad root")

	local isOpenCloud = NevermoreTestRunnerUtils.isOpenCloud()

	if isOpenCloud then
		print("[NevermoreTestRunner] Running in Open Cloud execution context")
		NevermoreTestRunnerUtils._runTestsAsync(root)
	else
		print("[NevermoreTestRunner] Running in local execution context")
		local ok, err = pcall(function(): any
			return NevermoreTestRunnerUtils._runTestsAsync(root)
		end)
		local ProcessService = (game :: any):GetService("ProcessService")
		if ok then
			(ProcessService :: any):ExitAsync(0)
		else
			warn(tostring(err));
			(ProcessService :: any):ExitAsync(1)
		end
	end
end

function NevermoreTestRunnerUtils._runTestsAsync(root: Instance)
	local config = root:FindFirstChild("jest.config", true)
	if not config or not config.Parent then
		print("[NevermoreTestRunner] No jest.config found — smoke test passed (boot success)")
		return
	end

	local projectRoot = config.Parent
	print("[NevermoreTestRunner] Running Jest tests from:", projectRoot:GetFullName())
	local status, result = (Jest :: any)
		.runCLI(projectRoot, {
			verbose = true,
			ci = true,
			testPathIgnorePatterns = { "/node_modules/" },
		}, { projectRoot })
		:awaitStatus()

	if status == "Rejected" then
		local message = "Jest run failed"
		if typeof(result) == "table" and result.message then
			message = result.message
		elseif typeof(result) == "string" then
			message = result
		end
		error("[NevermoreTestRunner] " .. message)
	end

	if typeof(result) == "table" and result.numFailedTests and result.numFailedTests > 0 then
		error(string.format("[NevermoreTestRunner] %d test(s) failed", result.numFailedTests))
	end
end

return NevermoreTestRunnerUtils
