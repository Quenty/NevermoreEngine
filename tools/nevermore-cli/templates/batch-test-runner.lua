-- batch-test-runner.lua
-- Runs all test scripts sequentially in a single execution task.
-- PACKAGE_SLUGS_JSON placeholder is replaced with a JSON array of slug strings at runtime.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- stylua: ignore
local packageSlugs: { string } = HttpService:JSONDecode([==[{{ PACKAGE_SLUGS_JSON }}]==])

-- Discover test scripts via tags (set by combine-test-places.lua)
local scriptSources = {}
for _, slug in packageSlugs do
	local tagged = CollectionService:GetTagged(`_BatchTest_{slug}`)
	local inst = tagged[1]
	if inst then
		scriptSources[slug] = inst.Source
	else
		warn(`[BatchTest] Failed to find script source for {slug}`)
	end
end

-- Snapshot all package roots (keep references even when unparented)
local allPackages = {}
for _, child in ServerScriptService:GetChildren() do
	allPackages[child.Name] = child
end

-- Tag on a NevermoreTestRunnerUtils results table. A test script returns one;
-- one written before the convention returns nil, and a probe returns whatever
-- it likes, so only a tagged table is read as results.
local RESULTS_FORMAT = "nevermore-test-results@1"

type TestCounts = {
	passed: number,
	failed: number,
	skipped: number,
	total: number,
	suitesPassed: number,
	suitesFailed: number,
	suitesTotal: number,
}

type Result = {
	success: boolean,
	slug: string,
	durationMs: number,
	error: string?,
	-- Absent when the package's test script returned nothing structured, which
	-- is the only case where a reader still has to fall back to its logs.
	counts: TestCounts?,
	-- False for a smoke test, whose counts are zero because nothing counted them.
	-- Carried so a reader never has to guess whether zero means "no tests".
	ranJest: boolean?,
}

-- Counts only. This summary is printed as one log line and read back by the
-- CLI, so it stays short enough to survive whatever the engine does to a long
-- line; the failure text a run also returns is per-package and already in that
-- package's own log section.
local function toCounts(returned: any): TestCounts?
	if type(returned) ~= "table" or returned.format ~= RESULTS_FORMAT then
		return nil
	end

	local counts: { [string]: number } = {}
	for _, field in { "passed", "failed", "skipped", "total", "suitesPassed", "suitesFailed", "suitesTotal" } do
		if type(returned[field]) ~= "number" then
			return nil
		end
		counts[field] = returned[field]
	end

	return counts :: any
end

local function isStructuredFailure(returned: any): boolean
	return type(returned) == "table" and returned.format == RESULTS_FORMAT and returned.success ~= true
end

local results: { Result } = {}

for _, slug in packageSlugs do
	local scriptSource = scriptSources[slug]
	if not scriptSource then
		print("===BATCH_TEST_BEGIN " .. slug .. "===")
		warn(`[BatchTest] {slug}: No test script found for {slug}. Is it tagged with _BatchTest_{slug}?`)
		print("===BATCH_TEST_END " .. slug .. " FAIL 0===")
		table.insert(results, { slug = slug, success = false, durationMs = 0, error = "No test script found" })
		continue
	end

	-- ISOLATE: unparent all, show only this package
	for _, package in allPackages do
		package.Parent = nil
	end
	allPackages[slug].Parent = ServerScriptService

	-- Snapshot services for cleanup
	local preWorkspace = {}
	for _, child in workspace:GetChildren() do
		preWorkspace[child] = true
	end
	local preRunService = {}
	for _, child in ReplicatedStorage:GetChildren() do
		preRunService[child] = true
	end

	-- Yield before the BEGIN marker so deferred callbacks triggered by
	-- reparenting flush before the marker enters the log stream. This
	-- prevents Open Cloud log reordering from placing leaked output
	-- inside this package's section.
	RunService.Heartbeat:Wait()

	print("===BATCH_TEST_BEGIN " .. slug .. "===")

	-- Measure pcall execution time only. The surrounding cleanup/yield cost
	-- is amortized across all packages and would otherwise dominate fast tests.
	local startClock = os.clock()

	local testOk, returned = pcall(function()
		local fn, compileErr = loadstring(scriptSource, slug)
		if not fn then
			error("Compile error: " .. tostring(compileErr))
		end
		return fn()
	end)

	local durationMs = math.floor((os.clock() - startClock) * 1000 + 0.5)

	-- Yield before the END marker for the same reason: leaked deferred
	-- callbacks may fire during fn() and their output must land before
	-- the marker in the log stream.
	RunService.Heartbeat:Wait()

	-- CLEANUP: restore service state
	allPackages[slug].Parent = nil
	for _, child in workspace:GetChildren() do
		if not preWorkspace[child] and not child:IsA("Terrain") and not child:IsA("Camera") then
			pcall(child.Destroy, child)
		end
	end
	for _, child in ReplicatedStorage:GetChildren() do
		if not preRunService[child] then
			pcall(child.Destroy, child)
		end
	end
	-- Destroy injected LoaderLinks (non-archivable, created by LoaderLinkCreator)
	for _, desc in allPackages[slug]:GetDescendants() do
		if not desc.Archivable and desc:IsA("ModuleScript") and desc.Name == "loader" then
			pcall(desc.Destroy, desc)
		end
	end

	-- Flush lingering deferred callbacks. Heavy packages (Binder, ServiceBag)
	-- schedule deferred callbacks via CollectionService that survive cleanup.
	-- Yielding across multiple heartbeat frames is more reliable than a fixed
	-- time wait, since each frame drains its deferred queue.
	for _ = 1, 3 do
		RunService.Heartbeat:Wait()
	end

	-- A test script that does not throw has still failed if the results it
	-- returned say so, which is the whole reason it returns them: a failing suite
	-- used to announce itself by erroring, and an error carries no counts.
	local counts = if testOk then toCounts(returned) else nil
	local success = testOk and not isStructuredFailure(returned)
	local failureReason: string? = nil
	if not testOk then
		failureReason = tostring(returned)
	elseif not success then
		failureReason = tostring((returned :: any).error or "the test runner reported the run as failed")
	end

	if failureReason then
		warn("[BatchTest] " .. slug .. ": " .. failureReason)
	end
	print("===BATCH_TEST_END " .. slug .. (if success then " PASS " else " FAIL ") .. tostring(durationMs) .. "===")
	table.insert(results, {
		slug = slug,
		success = success,
		durationMs = durationMs,
		error = failureReason,
		counts = counts,
		ranJest = if counts then (returned :: any).ranJest == true else nil,
	})
end

-- Restore all packages
for _, package in allPackages do
	package.Parent = ServerScriptService
end

print("===BATCH_TEST_SUMMARY===")
print(HttpService:JSONEncode(results))
