--!strict
--[=[
	@class NevermoreTestResults

	Turns what Jest resolved with into the results table a test run returns.

	Deliberately dependency-free: no loader, no Jest, no `print` or `warn`. This
	logic has produced three bugs — counts read off the wrong table, jest-lua's
	inverted `success` field, and double-counted failed suites — every one of them
	shipped green because a module-scope Jest require made it impossible to unit
	test. It takes plain tables and returns plain tables so a test can drive it
	anywhere, including under Lune (see `test/results.test.luau`).

	The caller does the logging.
]=]

--[=[
	Tag identifying a [TestRunResults] table to whatever reads a run's return
	values. A test place also runs probe scripts that return whatever they like,
	so a reader matches on this rather than on the table's shape.

	@prop FORMAT string
	@within NevermoreTestResults
]=]
local FORMAT = "nevermore-test-results@1"

-- Results travel back as a value, and an oversize value fails the whole run
-- outright instead of arriving truncated, so the failure list is capped. The
-- full text of every failure is still in the logs.
local MAX_FAILURES = 25
local MAX_NAME_LENGTH = 300
local MAX_MESSAGE_LENGTH = 500

-- Every count the verdict reads or reports. All are initialised to 0 by
-- jest-lua's makeEmptyAggregatedTestResult and only ever incremented, so a real
-- AggregatedResult carries all of them as numbers. Requiring the whole set is
-- what makes a rename detectable: the first version of this required only
-- numTotalTests, so a rename of any other field would have zeroed the counts and
-- reported a pass, which is the bug it was written to prevent.
local REQUIRED_COUNTS = {
	"numTotalTests",
	"numPassedTests",
	"numFailedTests",
	"numPendingTests",
	"numTodoTests",
	"numTotalTestSuites",
	"numPassedTestSuites",
	"numFailedTestSuites",
	"numRuntimeErrorTestSuites",
}

local NevermoreTestResults = {}

NevermoreTestResults.FORMAT = FORMAT

--[=[
	One failed test, or one suite that failed before its tests could run.

	@interface TestFailure
	.name string -- Full test name, or the suite's script path for a suite-level failure
	.message string? -- First failure message, truncated
	@within NevermoreTestResults
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
	.format string -- Always [NevermoreTestResults.FORMAT]
	.success boolean -- Whether the run is a pass
	.ranJest boolean -- False for a smoke test, where the counts are all zero because nothing counted
	.passed number
	.failed number
	.skipped number -- Pending plus todo
	.total number
	.suitesPassed number
	.suitesFailed number
	.suitesTotal number
	.failures { TestFailure } -- Capped; `omittedFailures` says how many did not fit
	.omittedFailures number
	.error string? -- Why the run failed; absent on a pass
	@within NevermoreTestResults
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

--[[
	Finds the AggregatedResult in whatever Jest.runCLI resolved with.

	jest-lua resolves `{ globalConfig, results }`, so the counts live one level in.
	Reading the wrapper finds none of them, and a missing count that defaults to
	zero is indistinguishable from a clean run — which is how a wrong read of this
	shipped and reported every failing suite as a pass. Both shapes are accepted,
	and every count the verdict touches must be a number, so nothing can be read
	off a table that only half matches.
]]
local function findAggregatedResult(resolved: any): any?
	local function isAggregatedResult(candidate: any): boolean
		if typeof(candidate) ~= "table" then
			return false
		end
		for _, field in REQUIRED_COUNTS do
			if type(candidate[field]) ~= "number" then
				return false
			end
		end
		return true
	end

	if isAggregatedResult(resolved) then
		return resolved
	end

	if typeof(resolved) == "table" and isAggregatedResult(resolved.results) then
		return resolved.results
	end

	return nil
end

local function collectFailures(result: any): ({ TestFailure }, number)
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

--[=[
	Builds an all-zero passing result. Every other result is this with counts
	filled in, so a caller never has to handle a missing field.

	@param ranJest boolean
	@return TestRunResults
]=]
function NevermoreTestResults.new(ranJest: boolean): TestRunResults
	return {
		format = FORMAT,
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
	Builds a failed result carrying no counts, for a run that never produced any.

	@param ranJest boolean
	@param message string -- Why the run failed. Required: a failure with no reason is unreadable.
	@return TestRunResults
]=]
function NevermoreTestResults.failed(ranJest: boolean, message: string): TestRunResults
	local results = NevermoreTestResults.new(ranJest)
	results.success = false
	results.error = "[NevermoreTestRunner] " .. truncate(message, MAX_MESSAGE_LENGTH)

	return results
end

--[=[
	Reads the verdict and the counts out of whatever `Jest.runCLI` resolved with.

	Fails closed on anything it cannot read. Defaulting an unreadable count to
	zero instead is what let two wrong reads of this ship: no failures over no
	tests reads exactly like a clean run.

	@param resolved any -- The value Jest.runCLI's promise resolved with
	@return TestRunResults
]=]
function NevermoreTestResults.fromJest(resolved: any): TestRunResults
	local result = findAggregatedResult(resolved)
	if not result then
		return NevermoreTestResults.failed(
			true,
			"Jest resolved without a readable AggregatedResult, so this run has no counts and cannot be called a pass"
		)
	end

	local results = NevermoreTestResults.new(true)
	results.passed = result.numPassedTests
	results.failed = result.numFailedTests
	results.skipped = result.numPendingTests + result.numTodoTests
	results.total = result.numTotalTests
	results.suitesPassed = result.numPassedTestSuites
	-- Not added to numRuntimeErrorTestSuites. jest-lua increments both for one
	-- suite that failed to run (helpers.lua addResult: the runtime-error counter
	-- unconditionally, then numFailedTestSuites via the `numFailingTests > 0 or
	-- testExecError` branch), so summing them reports one broken suite as two —
	-- and "2 of 1 suite(s) failed" for a single-spec package.
	results.suitesFailed = result.numFailedTestSuites
	results.suitesTotal = result.numTotalTestSuites

	-- jest-lua derives numTotalTests as passing + failing + pending + todo per
	-- suite (helpers.lua addResult), so this holds by construction for every real
	-- result. It is asserted rather than assumed because it is the one check that
	-- catches a field this code reads being renamed or moved: validating names
	-- one by one only ever covers the names known when it was written, and both
	-- bugs that shipped here were a count silently arriving as zero.
	local counted = results.passed + results.failed + results.skipped
	if counted ~= results.total then
		return NevermoreTestResults.failed(
			true,
			string.format(
				"Jest's counts do not add up (%d passed + %d failed + %d skipped = %d, but it reports %d total), "
					.. "so they cannot be trusted to say whether this run passed",
				results.passed,
				results.failed,
				results.skipped,
				counted,
				results.total
			)
		)
	end

	results.failures, results.omittedFailures = collectFailures(result)

	-- A snapshot check can fail a run without failing a test, so the counts alone
	-- do not cover it.
	local snapshotFailed = typeof(result.snapshot) == "table" and result.snapshot.failure == true
	-- A suite both skipped and broken lands in numPendingTestSuites, never in
	-- numFailedTestSuites, so this is the only term that catches it.
	local suitesErrored = result.numRuntimeErrorTestSuites

	-- `result.success` is deliberately not consulted. jest-lua inverted it: its
	-- TestScheduler assigns `anyTestFailures or snapshot.failure or
	-- anyReporterErrors` where upstream jest negates that whole expression
	-- (TestScheduler.lua:434), so the field is true exactly when the run failed.
	-- Reading it either way is a trap — the sense flips the day the missing `not`
	-- is restored — so the underlying signals are read instead. The one signal
	-- that leaves no other trace is a reporter error, which the AggregatedResult
	-- does not expose at all.
	--
	-- A suite that dies before its first test contributes no failed test, and an
	-- interrupted run's counts describe only what it got through, so neither is
	-- visible in the test counts alone either.
	results.success = results.failed == 0
		and results.suitesFailed == 0
		and suitesErrored == 0
		and result.wasInterrupted ~= true
		and not snapshotFailed

	if not results.success then
		-- Built from the causes that actually hold, never formatted from counts
		-- that may be zero. "0 test(s) and 0 test suite(s) failed" was a real
		-- failure reason this used to emit, and a reason saying nothing failed is
		-- unreadable as either a pass or a failure — which is what made the bug
		-- behind it hard to see.
		local causes = {}
		if results.failed > 0 then
			table.insert(causes, string.format("%d test(s) failed", results.failed))
		end
		if results.suitesFailed > 0 then
			table.insert(causes, string.format("%d test suite(s) failed", results.suitesFailed))
		end
		if suitesErrored > 0 then
			table.insert(causes, string.format("%d test suite(s) failed to run", suitesErrored))
		end
		if result.wasInterrupted == true then
			table.insert(causes, "the run was interrupted")
		end
		if snapshotFailed then
			table.insert(causes, "a snapshot check failed")
		end
		if #causes == 0 then
			-- Unreachable while every condition above is also a cause here. If it
			-- is ever reached, the two lists have drifted apart, and saying so is
			-- worth more than a reason built out of zeros.
			table.insert(causes, "the run failed for a reason this runner could not identify")
		end

		results.error = "[NevermoreTestRunner] " .. table.concat(causes, ", ")
	end

	return results
end

return NevermoreTestResults
