--[[
	Simple Lune test runner for studio-bridge plugin modules.

	Usage:
	  lune run test/test-runner                      -- discover all *.test.luau in test/
	  lune run test/test-runner test/protocol.test   -- run specific test file(s)

	Each test file must return a list of { name: string, fn: () -> () } entries.
	A test passes if fn() completes without error; it fails if fn() throws.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

-- ---------------------------------------------------------------------------
-- Discover test files
-- ---------------------------------------------------------------------------

-- The directory containing this test-runner script.
-- debug.info(1, "s") returns the source path of the current chunk.
local scriptSource = debug.info(1, "s")
local scriptDir = string.match(scriptSource, "(.+/)") or "./"

local testFiles: { string } = {}
-- Parallel list of require paths (relative to this script, using ./ prefix)
local testRequirePaths: { string } = {}

if #process.args > 0 then
	for _, arg in process.args do
		-- Allow both "test/foo.test" and "test/foo.test.luau"
		local path = arg
		if not string.match(path, "%.luau$") then
			path = path .. ".luau"
		end
		table.insert(testFiles, path)

		-- Build a require path relative to this runner (./ prefix, no .luau)
		local name = string.match(path, "([^/]+)%.luau$") or path
		table.insert(testRequirePaths, "./" .. string.gsub(name, "%.luau$", ""))
	end
else
	-- Discover all *.test.luau files in the test/ directory (non-recursive).
	local entries = fs.readDir(scriptDir)
	for _, entry in entries do
		if string.match(entry, "%.test%.luau$") then
			table.insert(testFiles, scriptDir .. entry)
			-- require path relative to this script: ./filename (no extension)
			local name = string.gsub(entry, "%.luau$", "")
			table.insert(testRequirePaths, "./" .. name)
		end
	end
	table.sort(testFiles)
	-- Sort requirePaths in the same order
	table.sort(testRequirePaths)
end

if #testFiles == 0 then
	print("No test files found.")
	process.exit(1)
end

-- ---------------------------------------------------------------------------
-- Run tests
-- ---------------------------------------------------------------------------

local totalPassed = 0
local totalFailed = 0
local totalCount = 0

for i, filePath in testFiles do
	local requirePath = testRequirePaths[i]

	local ok, tests = pcall(require, requirePath)
	if not ok then
		print(string.format("\n[LOAD ERROR] %s: %s", filePath, tostring(tests)))
		totalFailed = totalFailed + 1
		totalCount = totalCount + 1
		continue
	end

	if type(tests) ~= "table" then
		print(string.format("\n[LOAD ERROR] %s: expected table, got %s", filePath, type(tests)))
		totalFailed = totalFailed + 1
		totalCount = totalCount + 1
		continue
	end

	print(string.format("\n--- %s ---", filePath))

	for _, test in tests do
		totalCount = totalCount + 1
		local pass, err = pcall(test.fn)
		if pass then
			totalPassed = totalPassed + 1
			print(string.format("  PASS  %s", test.name))
		else
			totalFailed = totalFailed + 1
			print(string.format("  FAIL  %s", test.name))
			print(string.format("        %s", tostring(err)))
		end
	end
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed, %d total", totalPassed, totalFailed, totalCount))

if totalFailed > 0 then
	process.exit(1)
end
