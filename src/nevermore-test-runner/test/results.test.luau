--[[
	Unit tests for NevermoreTestResults, run under Lune:

	  lune run src/nevermore-test-runner/test/results

	Self-contained on purpose — it needs no runner, no mocks and no Roblox, which
	is the whole reason the module under test has no dependencies. Three bugs have
	shipped from this logic (counts read off Jest's wrapper table, jest-lua's
	inverted `success` field, and failed suites counted twice), all of them green
	in CI, because it used to share a file with a module-scope Jest require and so
	could not be driven from a test at all.

	Exits non-zero on the first failure.
]]

local process = require("@lune/process")

local NevermoreTestResults = require("../src/Server/NevermoreTestResults")

local failures = 0
local passes = 0

local function check(name: string, ok: boolean, detail: string?)
	if ok then
		passes += 1
		print(`  ok  {name}`)
	else
		failures += 1
		print(`FAIL  {name}{if detail then ": " .. detail else ""}`)
	end
end

local function checkEqual(name: string, actual: any, expected: any)
	check(name, actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

--[[
	A realistic AggregatedResult. jest-lua derives numTotalTests as
	passing + failing + pending + todo, so the default is internally consistent
	and every override has to keep it that way.
]]
local function aggregated(overrides: { [string]: any }?): { [string]: any }
	local result: { [string]: any } = {
		numTotalTests = 311,
		numPassedTests = 311,
		numFailedTests = 0,
		numPendingTests = 0,
		numTodoTests = 0,
		numTotalTestSuites = 19,
		numPassedTestSuites = 19,
		numFailedTestSuites = 0,
		numRuntimeErrorTestSuites = 0,
		wasInterrupted = false,
		snapshot = { failure = false },
		testResults = {},
		-- jest-lua sets this to the *failure* condition, not to success
		-- (TestScheduler.lua:434). A passing run therefore carries `false`.
		success = false,
	}
	if overrides then
		for key, value in overrides do
			result[key] = value
		end
	end
	return result
end

--[[ Jest.runCLI resolves with { globalConfig, results }, not the result itself. ]]
local function resolved(result: { [string]: any }): { [string]: any }
	return { globalConfig = {}, results = result }
end

print("NevermoreTestResults.fromJest")

do
	local results = NevermoreTestResults.fromJest(resolved(aggregated()))

	checkEqual("passes a run where nothing failed", results.success, true)
	checkEqual("does not read jest-lua's inverted success field", results.error, nil)
	checkEqual("reads passed off the inner result", results.passed, 311)
	checkEqual("reads total off the inner result", results.total, 311)
	checkEqual("reads suite totals off the inner result", results.suitesTotal, 19)
	checkEqual("marks the run as having run jest", results.ranJest, true)
	checkEqual("tags the results", results.format, NevermoreTestResults.FORMAT)
end

do
	-- The shape upstream jest would resolve with, in case the wrapper ever goes.
	local results = NevermoreTestResults.fromJest(aggregated())

	checkEqual("accepts a bare AggregatedResult too", results.success, true)
	checkEqual("reads counts off a bare AggregatedResult", results.passed, 311)
end

do
	local results = NevermoreTestResults.fromJest(resolved(aggregated({
		numTotalTests = 311,
		numPassedTests = 309,
		numFailedTests = 2,
		numFailedTestSuites = 1,
		numPassedTestSuites = 18,
	})))

	checkEqual("fails a run with failed tests", results.success, false)
	checkEqual("reports the failed count", results.failed, 2)
	checkEqual("names both causes", results.error, "[NevermoreTestRunner] 2 test(s) failed, 1 test suite(s) failed")
end

do
	-- One suite that failed to run. jest-lua increments numRuntimeErrorTestSuites
	-- AND numFailedTestSuites for it, so adding them reports one suite as two.
	local results = NevermoreTestResults.fromJest(resolved(aggregated({
		numTotalTests = 0,
		numPassedTests = 0,
		numTotalTestSuites = 1,
		numPassedTestSuites = 0,
		numFailedTestSuites = 1,
		numRuntimeErrorTestSuites = 1,
	})))

	checkEqual("fails a run whose suite could not run", results.success, false)
	checkEqual("does not double-count a broken suite", results.suitesFailed, 1)
	check(
		"never reports more failed suites than exist",
		results.suitesFailed <= results.suitesTotal,
		`{results.suitesFailed} of {results.suitesTotal}`
	)
end

do
	-- A suite both skipped and broken lands in numPendingTestSuites, so
	-- numFailedTestSuites stays 0 and only the runtime-error count sees it.
	local results = NevermoreTestResults.fromJest(resolved(aggregated({
		numTotalTests = 0,
		numPassedTests = 0,
		numTotalTestSuites = 1,
		numPassedTestSuites = 0,
		numRuntimeErrorTestSuites = 1,
	})))

	checkEqual("fails a run on the runtime-error count alone", results.success, false)
	checkEqual("says the suite could not run", results.error, "[NevermoreTestRunner] 1 test suite(s) failed to run")
end

do
	local interrupted = NevermoreTestResults.fromJest(resolved(aggregated({ wasInterrupted = true })))
	checkEqual("fails an interrupted run", interrupted.success, false)
	checkEqual("says it was interrupted", interrupted.error, "[NevermoreTestRunner] the run was interrupted")

	local snapshot = NevermoreTestResults.fromJest(resolved(aggregated({ snapshot = { failure = true } })))
	checkEqual("fails a run whose snapshot check failed", snapshot.success, false)
	checkEqual("says the snapshot check failed", snapshot.error, "[NevermoreTestRunner] a snapshot check failed")
end

do
	-- Every failure reason must name something. "0 test(s) and 0 test suite(s)
	-- failed" was a real reason this used to emit.
	for _, result in
		{
			aggregated({ wasInterrupted = true }),
			aggregated({ snapshot = { failure = true } }),
			aggregated({ numRuntimeErrorTestSuites = 1 }),
		}
	do
		local results = NevermoreTestResults.fromJest(resolved(result))
		check(
			"never builds a reason out of zeros",
			results.error ~= nil and not string.find(results.error :: string, "0 test", 1, true),
			tostring(results.error)
		)
	end
end

print("NevermoreTestResults.fromJest — failing closed")

do
	-- Anything but a readable AggregatedResult. Every one of these used to be
	-- read as zero failures over zero tests, which is a pass.
	--
	-- A list of pairs, not a map: `["nil"] = nil` stores no entry at all, so a map
	-- would drop the nil case silently — a test that never runs.
	local missingFailedTests = aggregated()
	missingFailedTests.numFailedTests = nil

	local renamedFailedTests = aggregated()
	renamedFailedTests.numFailedTests = nil
	renamedFailedTests.numFailingTests = 0

	local unreadable: { { description: string, value: any } } = {
		{ description = "the wrapper alone", value = { globalConfig = {} } },
		{ description = "nil", value = nil },
		{ description = "a string", value = "done" },
		{ description = "a table with no counts", value = { success = true } },
		{ description = "a result missing numFailedTests", value = missingFailedTests },
		{ description = "a result whose numFailedTests was renamed", value = renamedFailedTests },
	}

	-- #unreadable would stop at the nil-valued entry, so the count is explicit.
	checkEqual("covers every unreadable shape", #unreadable, 6)

	for index = 1, 6 do
		local case = unreadable[index]
		local results = NevermoreTestResults.fromJest(case.value)
		check(`fails closed on {case.description}`, results.success == false, "reported a pass")
		check(`explains itself on {case.description}`, results.error ~= nil, "no reason given")
	end
end

do
	-- The invariant that catches a rename of any count, including ones this code
	-- does not know the name of yet.
	local results = NevermoreTestResults.fromJest(
		resolved(aggregated({ numTotalTests = 311, numPassedTests = 0, numFailedTests = 0 }))
	)

	checkEqual("fails closed when the counts do not add up", results.success, false)
	check(
		"says the counts do not add up",
		results.error ~= nil and string.find(results.error :: string, "do not add up", 1, true) ~= nil,
		tostring(results.error)
	)
end

print("NevermoreTestResults.new / .failed")

do
	local smoke = NevermoreTestResults.new(false)
	checkEqual("a smoke test passes", smoke.success, true)
	checkEqual("a smoke test did not run jest", smoke.ranJest, false)
	checkEqual("a passing result carries no error", smoke.error, nil)

	local failed = NevermoreTestResults.failed(true, "something broke")
	checkEqual("a failed result does not pass", failed.success, false)
	checkEqual("a failed result carries its reason", failed.error, "[NevermoreTestRunner] something broke")
end

print(`\n{passes} passed, {failures} failed`)

if failures > 0 then
	process.exit(1)
end
