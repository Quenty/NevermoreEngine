-- batch-test-runner.luau
-- Runs all test scripts sequentially in a single execution task.
-- PACKAGE_SLUGS_JSON placeholder is replaced with a JSON array of slug strings at runtime.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- stylua: ignore
local packageSlugs: { string } = HttpService:JSONDecode([==[{{ PACKAGE_SLUGS_JSON }}]==])

-- Discover test scripts via tags (set by combine-test-places.luau)
local scriptSources = {}
for _, slug in packageSlugs do
	local tagged = CollectionService:GetTagged(`_BatchTest_{slug}`)
	local inst = tagged[1]
	if inst then
		scriptSources[slug] = inst.Source
	else
		error(`Failed to find script source for {slug}`)
	end
end

-- Snapshot all package roots (keep references even when unparented)
local allPackages = {}
for _, child in ServerScriptService:GetChildren() do
	allPackages[child.Name] = child
end

type Result = {
	success: boolean,
	slug: string,
	error: string?,
}

local results: { Result } = {}

for _, slug in packageSlugs do
	local scriptSource = scriptSources[slug]
	if not scriptSource then
		warn(`[BatchTest] No script for {slug}`)
		print("===BATCH_TEST_BEGIN " .. slug .. "===")
		print("===BATCH_TEST_END " .. slug .. " FAIL===")
		table.insert(results, { slug = slug, success = false, error = "No test script found" })
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

	local testOk, testErr = pcall(function()
		local fn, compileErr = loadstring(scriptSource, slug)
		if not fn then
			error("Compile error: " .. tostring(compileErr))
		end
		fn()
	end)

	-- Yield before the END marker for the same reason: leaked deferred
	-- callbacks may fire during fn() and their output must land before
	-- the marker in the log stream.
	RunService.Heartbeat:Wait()

	if testOk then
		print("===BATCH_TEST_END " .. slug .. " PASS===")
		table.insert(results, { slug = slug, success = true })
	else
		warn("[BatchTest] " .. slug .. ": " .. tostring(testErr))
		print("===BATCH_TEST_END " .. slug .. " FAIL===")
		table.insert(results, { slug = slug, success = false, error = tostring(testErr) })
	end

	-- CLEANUP: restore service state
	allPackages[slug].Parent = nil
	for _, c in workspace:GetChildren() do
		if not preWorkspace[c] and not c:IsA("Terrain") and not c:IsA("Camera") then
			pcall(c.Destroy, c)
		end
	end
	for _, c in ReplicatedStorage:GetChildren() do
		if not preRunService[c] then
			pcall(c.Destroy, c)
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
end

-- Restore all packages
for _, package in allPackages do
	package.Parent = ServerScriptService
end

print("===BATCH_TEST_SUMMARY===")
print(HttpService:JSONEncode(results))
