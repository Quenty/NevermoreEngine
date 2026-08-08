-- combine-test-places.luau
-- Merges individually-built test .rbxl files into a single combined place.
--
-- Usage: lune run combine-test-places.luau <outputPath> <slug1> <rbxl1> <scriptPath1> [<slug2> <rbxl2> <scriptPath2> ...]
--
-- For each triple (slug, rbxl, scriptPath):
--   1. Deserializes the .rbxl
--   2. Reparents ServerScriptService children (the package root) into the combined ServerScriptService
--   3. Reads the test script file and creates a Script under ReplicatedStorage._BatchScripts
--
-- The injected script is the ONLY thing tagged `_BatchTest_<slug>`, because that tag is how
-- batch-test-runner picks what to execute and it can only execute one thing. This used to tag every
-- Script under ServerScriptService instead, which is the same script right up until a project has
-- two -- and then the runner ran whichever the tag happened to list first, silently testing nothing.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local outputPath = process.args[1]
if not outputPath then
	print("Usage: lune run combine-test-places.luau <outputPath> <slug> <rbxl> <scriptPath> ...")
	process.exit(1)
end

-- Parse remaining args as triples: slug, rbxlPath, scriptPath
local packages = {}
local i = 2
while i + 2 <= #process.args do
	table.insert(packages, {
		slug = process.args[i],
		rbxlPath = process.args[i + 1],
		scriptPath = process.args[i + 2],
	})
	i = i + 3
end

if #packages == 0 then
	print("No packages specified")
	process.exit(1)
end

-- Use the first package's place as the base (preserves DataModel properties)
local baseContents = fs.readFile(packages[1].rbxlPath)
local game = roblox.deserializePlace(baseContents)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

ServerScriptService.LoadStringEnabled = true

local batchScripts = roblox.Instance.new("Folder")
batchScripts.Name = "_BatchScripts"
batchScripts.Parent = ReplicatedStorage

-- Carries the package's entry point as source for the runner to loadstring. Never runs on its own:
-- a Script under ReplicatedStorage is inert, and the runner wants to choose when it runs anyway.
local function injectTestScript(pkg)
	if not fs.isFile(pkg.scriptPath) then
		print(`[CombinePlaces] No script template for {pkg.slug} at {pkg.scriptPath}`)
		process.exit(1)
	end

	local testScript = roblox.Instance.new("Script")
	testScript.Name = pkg.slug
	testScript.Source = fs.readFile(pkg.scriptPath)
	testScript:AddTag("_BatchTest_" .. pkg.slug)
	testScript.Parent = batchScripts
end

-- Process first package
injectTestScript(packages[1])

-- Process remaining packages: deserialize each and reparent ServerScriptService children.
-- NOTE: ObjectValues (links) within each package's subtree are preserved when the
-- whole subtree is reparented as a unit. This works because all ObjectValue targets
-- are siblings within the same tree. If this breaks in a future Lune version, the
-- fallback is to resolve ObjectValues after reparenting via Name/path lookups.
-- See docs/gotchas/tooling.md for details.
for idx = 2, #packages do
	local pkg = packages[idx]

	local contents = fs.readFile(pkg.rbxlPath)
	local pkgGame = roblox.deserializePlace(contents)
	local packageServerScriptService = pkgGame:GetService("ServerScriptService")
	local packageHttpService = pkgGame:GetService("HttpService")

	if packageHttpService.HttpEnabled then
		HttpService.HttpEnabled = true
	end

	injectTestScript(pkg)

	-- Reparent all ServerScriptService children (non-recursively, just move the roots)
	for _, child in packageServerScriptService:GetChildren() do
		child.Parent = ServerScriptService
	end
end

-- Serialize and write
local output = roblox.serializePlace(game)
fs.writeFile(outputPath, output)

print("[CombinePlaces] Combined " .. #packages .. " packages into " .. outputPath)
