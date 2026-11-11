--!nonstrict
--[[
	@class NevermoreTestResults.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local NevermoreTestResults = require("NevermoreTestResults")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

--[[
	A realistic AggregatedResult. jest-lua derives numTotalTests as
	passing + failing + pending + todo, so the default is internally consistent
	and every override has to keep it that way.
]]
local function aggregated(overrides)
	local result = {
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
local function resolved(result)
	return { globalConfig = {}, results = result }
end

describe("NevermoreTestResults.fromJest", function()
	it("passes a run where nothing failed", function()
		local results = NevermoreTestResults.fromJest(resolved(aggregated()))

		expect(results.success).toBe(true)
		expect(results.error).toBeNil()
	end)

	it("reads the counts off the inner result", function()
		local results = NevermoreTestResults.fromJest(resolved(aggregated()))

		expect(results.passed).toBe(311)
		expect(results.total).toBe(311)
		expect(results.suitesTotal).toBe(19)
		expect(results.ranJest).toBe(true)
		expect(results.format).toBe(NevermoreTestResults.FORMAT)
	end)

	it("accepts a bare AggregatedResult too", function()
		-- The shape upstream jest would resolve with, in case the wrapper ever goes.
		local results = NevermoreTestResults.fromJest(aggregated())

		expect(results.success).toBe(true)
		expect(results.passed).toBe(311)
	end)

	it("fails a run with failed tests and names both causes", function()
		local results = NevermoreTestResults.fromJest(resolved(aggregated({
			numTotalTests = 311,
			numPassedTests = 309,
			numFailedTests = 2,
			numFailedTestSuites = 1,
			numPassedTestSuites = 18,
		})))

		expect(results.success).toBe(false)
		expect(results.failed).toBe(2)
		expect(results.error).toBe("[NevermoreTestRunner] 2 test(s) failed, 1 test suite(s) failed")
	end)

	it("does not double-count a suite that failed to run", function()
		-- jest-lua increments numRuntimeErrorTestSuites AND numFailedTestSuites
		-- for one broken suite, so adding them reports it as two.
		local results = NevermoreTestResults.fromJest(resolved(aggregated({
			numTotalTests = 0,
			numPassedTests = 0,
			numTotalTestSuites = 1,
			numPassedTestSuites = 0,
			numFailedTestSuites = 1,
			numRuntimeErrorTestSuites = 1,
		})))

		expect(results.success).toBe(false)
		expect(results.suitesFailed).toBe(1)
		expect(results.suitesFailed <= results.suitesTotal).toBe(true)
	end)

	it("fails a run on the runtime-error count alone", function()
		-- A suite both skipped and broken lands in numPendingTestSuites, so
		-- numFailedTestSuites stays 0 and only the runtime-error count sees it.
		local results = NevermoreTestResults.fromJest(resolved(aggregated({
			numTotalTests = 0,
			numPassedTests = 0,
			numTotalTestSuites = 1,
			numPassedTestSuites = 0,
			numRuntimeErrorTestSuites = 1,
		})))

		expect(results.success).toBe(false)
		expect(results.error).toBe("[NevermoreTestRunner] 1 test suite(s) failed to run")
	end)

	it("fails an interrupted run", function()
		local results = NevermoreTestResults.fromJest(resolved(aggregated({ wasInterrupted = true })))

		expect(results.success).toBe(false)
		expect(results.error).toBe("[NevermoreTestRunner] the run was interrupted")
	end)

	it("fails a run whose snapshot check failed", function()
		local results = NevermoreTestResults.fromJest(resolved(aggregated({ snapshot = { failure = true } })))

		expect(results.success).toBe(false)
		expect(results.error).toBe("[NevermoreTestRunner] a snapshot check failed")
	end)

	it("never builds a failure reason out of zeros", function()
		-- "0 test(s) and 0 test suite(s) failed" was a real reason this emitted:
		-- a string that asserts nothing failed while failing the run.
		local cases = {
			aggregated({ wasInterrupted = true }),
			aggregated({ snapshot = { failure = true } }),
			aggregated({ numRuntimeErrorTestSuites = 1 }),
		}

		for _, case in cases do
			local results = NevermoreTestResults.fromJest(resolved(case))

			-- Captured first: string.find returns two values, and expect() takes one.
			local zeroCount = string.find(results.error, "0 test", 1, true)

			expect(results.error).never.toBeNil()
			expect(zeroCount).toBeNil()
		end
	end)
end)

describe("NevermoreTestResults.fromJest failing closed", function()
	--[[
		Anything but a readable AggregatedResult. Every one of these used to be
		read as zero failures over zero tests, which is a pass.
	]]
	local function unreadableCases()
		local missingFailedTests = aggregated()
		missingFailedTests.numFailedTests = nil

		local renamedFailedTests = aggregated()
		renamedFailedTests.numFailedTests = nil
		renamedFailedTests.numFailingTests = 0

		-- A list of pairs, not a map: `["nil"] = nil` stores no entry at all, so a
		-- map would drop the nil case silently — a test that never runs.
		return {
			{ description = "the wrapper alone", value = { globalConfig = {} } },
			{ description = "nil", value = nil },
			{ description = "a string", value = "done" },
			{ description = "a table with no counts", value = { success = true } },
			{ description = "a result missing numFailedTests", value = missingFailedTests },
			{ description = "a result whose numFailedTests was renamed", value = renamedFailedTests },
		}
	end

	it("covers every unreadable shape", function()
		-- #cases would stop at the nil-valued entry, so the count is asserted here
		-- rather than trusted below.
		expect(#unreadableCases()).toBe(6)
	end)

	it("fails closed on a shape it cannot read, and says why", function()
		local cases = unreadableCases()

		for index = 1, 6 do
			local results = NevermoreTestResults.fromJest(cases[index].value)

			expect(results.success).toBe(false)
			expect(results.error).never.toBeNil()
		end
	end)

	it("fails closed when the counts do not add up", function()
		-- The invariant that catches a rename of any count, including ones this
		-- code does not know the name of yet.
		local results = NevermoreTestResults.fromJest(resolved(aggregated({ numTotalTests = 311, numPassedTests = 0 })))

		local explained = string.find(results.error, "do not add up", 1, true)

		expect(results.success).toBe(false)
		expect(explained).never.toBeNil()
	end)
end)

describe("NevermoreTestResults.new / .failed", function()
	it("passes a smoke test that did not run jest", function()
		local smoke = NevermoreTestResults.new(false)

		expect(smoke.success).toBe(true)
		expect(smoke.ranJest).toBe(false)
		expect(smoke.error).toBeNil()
	end)

	it("carries the reason a failed result was given", function()
		local failed = NevermoreTestResults.failed(true, "something broke")

		expect(failed.success).toBe(false)
		expect(failed.error).toBe("[NevermoreTestRunner] something broke")
	end)
end)
