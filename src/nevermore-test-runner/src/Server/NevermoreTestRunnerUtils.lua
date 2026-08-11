--!strict
--[=[
	@class NevermoreTestRunnerUtils

	Unified test runner utilities for Nevermore packages.
	Handles both smoke tests (game boot) and Jest unit tests.

	- If a jest.config is found under the given root, runs Jest tests
	- If no jest.config is found, boot success is the test (smoke test)
	- Detects Open Cloud execution via OpenCloudService to control behavior

	A run reports itself by *returning* [TestRunResults], not by throwing. The
	engine truncates a long run's log output, so counts scraped back out of that
	text are exactly what goes missing on the runs where they matter most. A test
	script hands the table straight out of its top level:

	```lua
	local results = NevermoreTestRunnerUtils.runTestsIfNeededAsync(root)
	if results then
		return results
	end
	```
]=]

local require = require(script.Parent.loader).load(script)

local Jest = (require :: any)("Jest")

local RESULTS_FORMAT = "nevermore-test-results@1"

-- Results travel back as a value, and an oversize value fails the whole run
-- outright instead of arriving truncated, so the failure list is capped. The
-- full text of every failure is still in the logs.
local MAX_FAILURES = 25
local MAX_NAME_LENGTH = 300
local MAX_MESSAGE_LENGTH = 500

local NevermoreTestRunnerUtils = {}

--[=[
	Tag identifying a [TestRunResults] table to whatever reads a run's return
	values. A test place also runs probe scripts that return whatever they like,
	so a reader matches on this rather than on the table's shape.

	@prop RESULTS_FORMAT string
	@within NevermoreTestRunnerUtils
]=]
NevermoreTestRunnerUtils.RESULTS_FORMAT = RESULTS_FORMAT

--[=[
	One failed test, or one suite that failed before its tests could run.

	@interface TestFailure
	.name string -- Full test name, or the suite's script path for a suite-level failure
	.message string? -- First failure message, truncated
	@within NevermoreTestRunnerUtils
]=]
export type TestFailure = {
	name: string,
	message: string?,
}

--[=[
	What a test run produced. Only ever plain strings, numbers, booleans and
	tables of those: the cloud and the Studio bridge marshal exotic values
	differently, and this subset survives both unchanged.

	@interface TestRunResults
	.format string -- Always [NevermoreTestRunnerUtils.RESULTS_FORMAT]
	.success boolean -- Whether the run is a pass
	.ranJest boolean -- False for a smoke test, where the counts are all zero because nothing counted them
	.passed number
	.failed number
	.skipped number -- Pending plus todo
	.total number
	.suitesPassed number
	.suitesFailed number
	.suitesTotal number
	.failures { TestFailure } -- Capped; `omittedFailures` says how many did not fit
	.omittedFailures number
	.error string? -- Why the run failed when no individual test can say so
	@within NevermoreTestRunnerUtils
]=]
export type TestRunResults = {
	format: string,
	success: boolean,
	ranJest: boolean,
	passed: number,
	failed: number,
	skipped: number,
	total: number,
	suitesPassed: number,
	suitesFailed: number,
	suitesTotal: number,
	failures: { TestFailure },
	omittedFailures: number,
	error: string?,
}

local function truncate(text: string, limit: number): string
	if #text <= limit then
		return text
	end

	return string.sub(text, 1, limit) .. "..."
end

local function toCount(value: any): number
	return if type(value) == "number" then value else 0
end

--[=[
	Finds the AggregatedResult in whatever Jest.runCLI resolved with.

	jest-lua resolves `{ globalConfig, results }` and the counts live on the inner
	`results`. Reading the wrapper finds no `numTotalTests` and every count comes
	back zero, which is indistinguishable from a run that passed — this is why the
	`numFailedTests > 0` check this module used to gate `error()` on never fired
	once. Both shapes are accepted so a jest-lua change cannot silently zero the
	counts again, and an unrecognized shape returns nil so the caller can refuse
	to call it a pass.

	Note `numTotalTests == 0` is a recognized result: a package with no specs ran
	and found nothing, which is a legitimate pass. Only a *missing* count means
	the shape is not understood.
]=]
local function findAggregatedResult(resolved: any): any?
	if typeof(resolved) ~= "table" then
		return nil
	end

	if type(resolved.numTotalTests) == "number" then
		return resolved
	end

	local inner = resolved.results
	if typeof(inner) == "table" and type(inner.numTotalTests) == "number" then
		return inner
	end

	return nil
end

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
	Builds an all-zero passing result. Every other result is this with counts
	filled in, so a caller never has to handle a missing field.

	@param ranJest boolean
	@return TestRunResults
]=]
function NevermoreTestRunnerUtils.newResults(ranJest: boolean): TestRunResults
	return {
		format = RESULTS_FORMAT,
		success = true,
		ranJest = ranJest,
		passed = 0,
		failed = 0,
		skipped = 0,
		total = 0,
		suitesPassed = 0,
		suitesFailed = 0,
		suitesTotal = 0,
		failures = {},
		omittedFailures = 0,
	}
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
	@return TestRunResults?
]=]
function NevermoreTestRunnerUtils.runTestsIfNeededAsync(root: Instance): TestRunResults?
	assert(typeof(root) == "Instance", "Bad root")

	local isOpenCloud = NevermoreTestRunnerUtils.isOpenCloud()
	local canReadSource = NevermoreTestRunnerUtils.canReadScriptSource()
	if not canReadSource then
		return nil
	end

	if isOpenCloud then
		print("[NevermoreTestRunner] Running in Open Cloud execution context")

		return NevermoreTestRunnerUtils._runTestsAsync(root)
	end

	print("[NevermoreTestRunner] Running in local execution context")
	local ok, returned = pcall(function(): any
		return NevermoreTestRunnerUtils._runTestsAsync(root)
	end)

	local results: TestRunResults
	if ok then
		results = returned
	else
		warn(tostring(returned))
		results = NevermoreTestRunnerUtils.newResults(false)
		results.success = false
		results.error = truncate(tostring(returned), MAX_MESSAGE_LENGTH)
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

		return NevermoreTestRunnerUtils.newResults(false)
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

		local results = NevermoreTestRunnerUtils.newResults(true)
		results.success = false
		results.error = truncate("[NevermoreTestRunner] " .. message, MAX_MESSAGE_LENGTH)
		warn(results.error)

		return results
	end

	return NevermoreTestRunnerUtils._resultsFromJest(result)
end

function NevermoreTestRunnerUtils._resultsFromJest(resolved: any): TestRunResults
	local results = NevermoreTestRunnerUtils.newResults(true)

	-- Fail closed on a shape this cannot read. Defaulting the counts to zero
	-- instead is what let a wrong read of the result go unnoticed: no failures
	-- and no tests reads exactly like a clean run, so the mistake shipped green.
	local result = findAggregatedResult(resolved)
	if not result then
		results.success = false
		results.error = "[NevermoreTestRunner] Jest resolved without a readable AggregatedResult, "
			.. "so this run has no counts and cannot be called a pass"
		warn(results.error)

		return results
	end

	results.passed = toCount(result.numPassedTests)
	results.failed = toCount(result.numFailedTests)
	results.skipped = toCount(result.numPendingTests) + toCount(result.numTodoTests)
	results.total = toCount(result.numTotalTests)
	results.suitesPassed = toCount(result.numPassedTestSuites)
	results.suitesFailed = toCount(result.numFailedTestSuites) + toCount(result.numRuntimeErrorTestSuites)
	results.suitesTotal = toCount(result.numTotalTestSuites)
	results.failures, results.omittedFailures = NevermoreTestRunnerUtils._collectFailures(result)

	-- A suite that dies before its first test contributes no failed test, and an
	-- interrupted run's counts describe only what it got through, so neither is
	-- visible in the test counts alone.
	results.success = results.failed == 0
		and results.suitesFailed == 0
		and result.wasInterrupted ~= true
		and result.success ~= false

	-- Printed as well as returned. It is the one line that proves the counts were
	-- read off a result this module understood, whatever happens to the return
	-- channel on the way out.
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

	if not results.success then
		if result.wasInterrupted == true then
			results.error = "[NevermoreTestRunner] Jest run was interrupted"
		else
			results.error = string.format(
				"[NevermoreTestRunner] %d test(s) and %d test suite(s) failed",
				results.failed,
				results.suitesFailed
			)
		end
		warn(results.error)
	end

	return results
end

function NevermoreTestRunnerUtils._collectFailures(result: any): ({ TestFailure }, number)
	local failures: { TestFailure } = {}
	local omitted = 0

	local function add(name: string, message: string?)
		if #failures >= MAX_FAILURES then
			omitted += 1
			return
		end

		table.insert(failures, {
			name = truncate(name, MAX_NAME_LENGTH),
			message = if message then truncate(message, MAX_MESSAGE_LENGTH) else nil,
		})
	end

	local testResults = result.testResults
	if type(testResults) ~= "table" then
		return failures, omitted
	end

	for _, suite in testResults do
		if type(suite) ~= "table" then
			continue
		end

		local execError = suite.testExecError
		if type(execError) == "table" then
			add(tostring(suite.testFilePath or "<unknown suite>"), tostring(execError.message or "suite failed to run"))
		end

		local assertions = suite.testResults
		if type(assertions) ~= "table" then
			continue
		end

		for _, assertion in assertions do
			if type(assertion) ~= "table" or assertion.status ~= "failed" then
				continue
			end

			local message: string? = nil
			local messages = assertion.failureMessages
			if type(messages) == "table" and type(messages[1]) == "string" then
				message = messages[1]
			end

			add(tostring(assertion.fullName or assertion.title or "<unnamed test>"), message)
		end
	end

	return failures, omitted
end

return NevermoreTestRunnerUtils
