--[[
	Smoke test script for integration games.
	Collects all Script descendants of ServerScriptService, spawns each
	via task.spawn(loadstring()) so they run concurrently (matching real
	game boot behavior), then waits for errors to surface.

	Output format is compatible with parseTestLogs (success = no "Stack Begin"
	patterns and no "Tests: N failed" lines).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local SETTLE_TIME = 30

-- Collect eligible scripts (non-disabled, non-empty, only server Scripts)
local scripts = {}
for _, descendant in ServerScriptService:GetDescendants() do
	if descendant:IsA("Script") and not descendant:IsA("LocalScript") and not descendant:IsA("ModuleScript") then
		if descendant.Disabled then
			continue
		end
		local source = descendant.Source
		if source == "" then
			continue
		end
		table.insert(scripts, descendant)
	end
end

local failed = 0
local errors = {}

-- Spawn each script concurrently, like the real engine would
for _, serverScript in scripts do
	local scriptName = serverScript:GetFullName()
	local fn, compileError = loadstring(serverScript.Source, scriptName)
	if not fn then
		failed += 1
		table.insert(errors, {
			script = scriptName,
			error = "Compile error: " .. tostring(compileError),
		})
		continue
	end

	task.spawn(function()
		local ok, runtimeError = pcall(fn)
		if not ok then
			failed += 1
			table.insert(errors, {
				script = scriptName,
				error = tostring(runtimeError),
			})
		end
	end)
end

-- Let spawned scripts run and settle — errors from yielding code
-- (e.g. WaitForChild, async service calls) surface during this window
task.wait(SETTLE_TIME)

-- Report results
local total = #scripts
local passed = total - failed

print("=== Smoke Test Results ===")
print(string.format("Scripts found: %d", total))
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))

if #errors > 0 then
	print("")
	for _, err in errors do
		print(string.format("FAIL %s", err.script))
		print(string.format("  %s", err.error))
	end
end

if failed > 0 then
	print(string.format("\nTests: %d failed, %d total", failed, total))
else
	print(string.format("\nTests: %d passed, %d total", passed, total))
end
