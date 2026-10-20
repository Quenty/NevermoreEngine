--[[
	Runs every package's test script sequentially in one execution task, isolating
	each package under ServerScriptService and cleaning up after it.

	PACKAGE_SLUGS_JSON is replaced with a JSON array of slugs at runtime. Test
	scripts are found by the `_BatchTest_<slug>` tag set by combine-test-places.lua.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BatchTestRunnerUtils = {}

-- stylua: ignore
local PACKAGE_SLUGS: { PackageSlug } = HttpService:JSONDecode([==[{{ PACKAGE_SLUGS_JSON }}]==])
local RESULTS_FORMAT = "nevermore-test-results@1"
local STATE_MODULE_NAME = "NevermoreTestRunnerState.global"
local COUNT_FIELDS = { "passed", "failed", "skipped", "total", "suitesPassed", "suitesFailed", "suitesTotal" }

type PackageSlug = string
type PackageLookupMap = { [PackageSlug]: Instance }
type ScriptSourceLookupMap = { [PackageSlug]: string }

type TestResult = {
	success: boolean,
	slug: PackageSlug,
	durationMs: number,
	error: string?,
	counts: TestCountsResult?,
	ranJest: boolean?,
}

type TestCountsResult = {
	passed: number,
	failed: number,
	skipped: number,
	total: number,
	suitesPassed: number,
	suitesFailed: number,
	suitesTotal: number,
}

function BatchTestRunnerUtils.getScriptSourceLookupMap(slugs: { PackageSlug }): ScriptSourceLookupMap
	local scriptSourceLookupMap: ScriptSourceLookupMap = {}
	for _, slug in slugs do
		local inst = CollectionService:GetTagged(`_BatchTest_{slug}`)[1]
		if inst then
			scriptSourceLookupMap[slug] = (inst :: Script).Source
		else
			warn(`[BatchTest] Failed to find script source for {slug}`)
		end
	end
	return table.freeze(scriptSourceLookupMap)
end

function BatchTestRunnerUtils.detachPackages(): (PackageLookupMap, () -> ())
	local packageLookupMap: PackageLookupMap = {}
	for _, child in ServerScriptService:GetChildren() do
		packageLookupMap[child.Name] = child
		child.Parent = nil
	end
	table.freeze(packageLookupMap)

	local function restore()
		for _, package in packageLookupMap do
			package.Parent = ServerScriptService
		end
	end

	return packageLookupMap, restore
end

function BatchTestRunnerUtils.toSet<T>(list: { T }): { [T]: true }
	local set: { [T]: true } = {}
	for _, item in list do
		set[item] = true
	end
	return table.freeze(set)
end

function BatchTestRunnerUtils.isolatePackage(package: Instance): () -> ()
	package.Parent = ServerScriptService

	local preWorkspace = BatchTestRunnerUtils.toSet(workspace:GetChildren())
	local preReplicatedStorage = BatchTestRunnerUtils.toSet(ReplicatedStorage:GetChildren())

	return function()
		package.Parent = nil

		for _, child in workspace:GetChildren() do
			if not preWorkspace[child] and not child:IsA("Terrain") and not child:IsA("Camera") then
				pcall(child.Destroy, child)
			end
		end
		for _, child in ReplicatedStorage:GetChildren() do
			if not preReplicatedStorage[child] then
				pcall(child.Destroy, child)
			end
		end
		for _, desc in package:GetDescendants() do
			if not desc.Archivable and desc:IsA("ModuleScript") and desc.Name == "loader" then
				pcall(desc.Destroy, desc)
			end
		end
	end
end

function BatchTestRunnerUtils.resetTestResultsMailbox(package: Instance): any
	local found = package:FindFirstChild(STATE_MODULE_NAME, true)
	if not (found and found:IsA("ModuleScript")) then
		return nil
	end

	local state = (require :: any)(found)
	state.results = nil
	return state
end

function BatchTestRunnerUtils.isFailedTestResult(returned: any): boolean
	return type(returned) == "table" and returned.format == RESULTS_FORMAT and returned.success ~= true
end

function BatchTestRunnerUtils.readTestResultCounts(returned: any): TestCountsResult?
	if type(returned) ~= "table" or returned.format ~= RESULTS_FORMAT then
		return nil
	end

	local counts: { [string]: number } = {}
	for _, field in COUNT_FIELDS do
		if type(returned[field]) ~= "number" then
			return nil
		end
		counts[field] = returned[field]
	end

	return table.freeze(counts) :: any
end

function BatchTestRunnerUtils.createTestResult(
	slug: PackageSlug,
	testOk: boolean,
	returned: any,
	state: any,
	durationMs: number
): TestResult
	local mailboxResults = if state then state.results else nil
	local reported = if testOk and BatchTestRunnerUtils.readTestResultCounts(returned) then returned else mailboxResults

	local counts = if testOk then BatchTestRunnerUtils.readTestResultCounts(reported) else nil
	local success = testOk and not BatchTestRunnerUtils.isFailedTestResult(reported)
	local failureReason: string? = nil
	if not testOk then
		failureReason = tostring(returned)
	elseif not success then
		failureReason = tostring((reported :: any).error or "the test runner reported the run as failed")
	end

	return table.freeze({
		slug = slug,
		success = success,
		durationMs = durationMs,
		error = failureReason,
		counts = counts,
		ranJest = if counts then (reported :: any).ranJest == true else nil,
	})
end

function BatchTestRunnerUtils.reportMissingScriptResult(slug: PackageSlug): TestResult
	print("===BATCH_TEST_BEGIN " .. slug .. "===")
	warn(`[BatchTest] {slug}: No test script found for {slug}. Is it tagged with _BatchTest_{slug}?`)
	print("===BATCH_TEST_END " .. slug .. " FAIL 0===")
	return table.freeze({ slug = slug, success = false, durationMs = 0, error = "No test script found" })
end

function BatchTestRunnerUtils.runScriptTimed(slug: PackageSlug, scriptSource: string): (boolean, any, number)
	local startClock = os.clock()

	local ok, returned = pcall(function()
		local fn, compileErr = loadstring(scriptSource, slug)
		if not fn then
			error("Compile error: " .. tostring(compileErr))
		end
		return fn()
	end)

	local durationMs = math.floor((os.clock() - startClock) * 1000 + 0.5)
	return ok, returned, durationMs
end

function BatchTestRunnerUtils.runPackage(
	packageLookupMap: PackageLookupMap,
	slug: PackageSlug,
	scriptSource: string?
): TestResult
	if not scriptSource then
		return BatchTestRunnerUtils.reportMissingScriptResult(slug)
	end

	local package = packageLookupMap[slug]
	local restore = BatchTestRunnerUtils.isolatePackage(package)

	RunService.Heartbeat:Wait()
	print("===BATCH_TEST_BEGIN " .. slug .. "===")

	local state = BatchTestRunnerUtils.resetTestResultsMailbox(package)
	local testOk, returned, durationMs = BatchTestRunnerUtils.runScriptTimed(slug, scriptSource)

	RunService.Heartbeat:Wait()
	restore()

	for _ = 1, 3 do
		RunService.Heartbeat:Wait()
	end

	local result = BatchTestRunnerUtils.createTestResult(slug, testOk, returned, state, durationMs)
	if result.error then
		warn("[BatchTest] " .. slug .. ": " .. result.error)
	end
	print(
		"===BATCH_TEST_END " .. slug .. (if result.success then " PASS " else " FAIL ") .. tostring(durationMs) .. "==="
	)

	return result
end

function BatchTestRunnerUtils.printResultsSummary(results: { TestResult })
	print("===BATCH_TEST_SUMMARY===")
	print(HttpService:JSONEncode(results))
end

local scriptSourceLookupMap = BatchTestRunnerUtils.getScriptSourceLookupMap(PACKAGE_SLUGS)
local packageLookupMap, restorePackages = BatchTestRunnerUtils.detachPackages()

local results: { TestResult } = {}
for _, slug in PACKAGE_SLUGS do
	table.insert(results, BatchTestRunnerUtils.runPackage(packageLookupMap, slug, scriptSourceLookupMap[slug]))
end
table.freeze(results)

restorePackages()
BatchTestRunnerUtils.printResultsSummary(results)

return results
