--!strict
--[=[
	@class NevermoreTestRunnerUtils

	Unified test runner utilities for Nevermore packages.
	Handles both smoke tests (game boot) and Jest unit tests.

	- If a jest.config is found under the given root, runs Jest tests
	- If no jest.config is found, boot success is the test (smoke test)
	- Detects Open Cloud execution via OpenCloudService to control behavior

	A run reports itself by *returning* [NevermoreTestResults.TestRunResults], not
	by throwing. The engine truncates a long run's log output, so counts scraped
	back out of that text are exactly what goes missing on the runs where they
	matter most. A test script hands the table straight out of its top level:

	```lua
	local results = NevermoreTestRunnerUtils.runTestsIfNeededAsync(root)
	if results then
		return results
	end
	```

	Reading Jest's result into that table is [NevermoreTestResults]'s job, which
	is a separate module so it can be unit tested without Jest present.
]=]

local require = require(script.Parent.loader).load(script)

local NevermoreTestResults = require("NevermoreTestResults")

local Jest = (require :: any)("Jest")

local NevermoreTestRunnerUtils = {}

--[=[
	Tag identifying a results table to whatever reads a run's return values.

	@prop RESULTS_FORMAT string
	@within NevermoreTestRunnerUtils
]=]
NevermoreTestRunnerUtils.RESULTS_FORMAT = NevermoreTestResults.FORMAT

export type TestFailure = NevermoreTestResults.TestFailure
export type TestRunResults = NevermoreTestResults.TestRunResults

--[=[
	Returns true if running inside an Open Cloud Luau Execution context.
]=]
function NevermoreTestRunnerUtils.isOpenCloud(): boolean
	local success, _ = pcall(function()
		return game:GetService("OpenCloudService")
	end)

	return success
end

function NevermoreTestRunnerUtils.canReadScriptSource(): boolean
	local success, _ = pcall(function()
		local _ = script.Source
	end)

	return success
end

--[=[
	Runs Jest tests if a jest.config is found under root. Otherwise treats
	boot success as the test (smoke test).

	Returns nil when no test run was attempted, which is how a real game server
	tells itself apart from a test place: script sources are unreadable there, so
	the caller falls through to its normal boot instead.

	Outside Open Cloud (e.g. Studio via studio-bridge) nothing reads the returned
	results, so ProcessService:ExitAsync() carries the verdict out instead.

	@param root Instance -- The instance to scan for jest.config (e.g. the package folder in ServerScriptService)
	@return NevermoreTestResults.TestRunResults?
]=]
function NevermoreTestRunnerUtils.runTestsIfNeededAsync(root: Instance): TestRunResults?
	assert(typeof(root) == "Instance", "Bad root")

	local isOpenCloud = NevermoreTestRunnerUtils.isOpenCloud()
	local canReadSource = NevermoreTestRunnerUtils.canReadScriptSource()
	if not canReadSource then
		return nil
	end

	if isOpenCloud then
		return NevermoreTestRunnerUtils._runTestsAsync(root)
	end

	local ok, returned = pcall(function(): any
		return NevermoreTestRunnerUtils._runTestsAsync(root)
	end)

	local results: TestRunResults
	if ok then
		results = returned
	else
		results = NevermoreTestResults.failed(false, tostring(returned))
		warn(results.error)
	end

	local exitCode = if results.success then 0 else 1
	local processService = (game :: any):GetService("ProcessService")
	if processService then
		(processService :: any):ExitAsync(exitCode)
	end

	return results
end

function NevermoreTestRunnerUtils._runTestsAsync(root: Instance): TestRunResults
	local config = root:FindFirstChild("jest.config", true)
	if not config or not config.Parent then
		print("[NevermoreTestRunner] No jest.config found — smoke test passed (boot success)")

		return NevermoreTestResults.new(false)
	end

	local projectRoot = config.Parent
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

		local rejected = NevermoreTestResults.failed(true, message)
		warn(rejected.error)

		return rejected
	end

	local results = NevermoreTestResults.fromJest(result)

	-- Printed as well as returned, and the only status line worth its bytes. In an
	-- aggregated batch every print competes for the engine's log buffer, so the
	-- "running in X context" and "running jest from Y" lines were dropped: nothing
	-- reads them, and they cost ~12 KB of the window per run. This one stays
	-- because it prints after jest's own summary, and truncation keeps the tail —
	-- so when the window closes over a package it is the count most likely to
	-- survive, and the one that proves the runner understood the result it read.
	print(
		string.format(
			"[NevermoreTestRunner] Results: %d passed, %d failed, %d skipped, %d total; %d of %d suite(s) failed",
			results.passed,
			results.failed,
			results.skipped,
			results.total,
			results.suitesFailed,
			results.suitesTotal
		)
	)

	if results.error then
		warn(results.error)
	end

	return results
end

return NevermoreTestRunnerUtils
