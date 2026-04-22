-- combine-test-places.luau
-- Merges individually-built test .rbxl files into a single combined place.
--
-- Usage: lune run combine-test-places.luau <outputPath> <slug1> <rbxl1> <scriptPath1> [<slug2> <rbxl2> <scriptPath2> ...]
--
-- For each triple (slug, rbxl, scriptPath):
--   1. Deserializes the .rbxl
--   2. Reparents SSS children (the package root) into the combined SSS
--   3. Reads the test script file and creates a Script under RS._BatchScripts

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
local sss = game:GetService("ServerScriptService")

-- Enable LoadStringEnabled on SSS
sss:SetAttribute("LoadStringEnabled", true)

-- Create _BatchScripts folder in ReplicatedStorage
local rs = game:GetService("ReplicatedStorage")
local batchScriptsFolder = roblox.Instance.new("Folder")
batchScriptsFolder.Name = "_BatchScripts"
batchScriptsFolder.Parent = rs

-- Process the first package (already loaded as the base)
do
	local pkg = packages[1]

	-- SSS children are already in place from the base build.
	-- Read the test script and add to _BatchScripts.
	local scriptSource = fs.readFile(pkg.scriptPath)
	local scriptInst = roblox.Instance.new("Script")
	scriptInst.Name = pkg.slug
	scriptInst:AddTag("_BatchTest_" .. pkg.slug)
	local ok, err = pcall(function()
		(scriptInst :: any).Source = scriptSource
	end)
	if not ok then
		warn("[CombinePlaces] Cannot set Source on " .. pkg.slug .. ": " .. tostring(err))
		scriptInst:SetAttribute("ScriptSource", scriptSource)
	end
	scriptInst.Parent = batchScriptsFolder
end

-- Process remaining packages: deserialize each and reparent SSS children.
-- NOTE: ObjectValues (links) within each package's subtree are preserved when the
-- whole subtree is reparented as a unit. This works because all ObjectValue targets
-- are siblings within the same tree. If this breaks in a future Lune version, the
-- fallback is to resolve ObjectValues after reparenting via Name/path lookups.
-- See docs/gotchas/tooling.md for details.
for idx = 2, #packages do
	local pkg = packages[idx]

	local contents = fs.readFile(pkg.rbxlPath)
	local pkgGame = roblox.deserializePlace(contents)
	local pkgSSS = pkgGame:GetService("ServerScriptService")

	-- Reparent all SSS children (non-recursively, just move the roots)
	for _, child in pkgSSS:GetChildren() do
		-- Skip Script instances (these are test entry points, not package roots)
		if child.ClassName == "Script" and child.Name == "Script" then
			continue
		end
		child.Parent = sss
	end

	-- Read the test script and add to _BatchScripts
	local scriptSource = fs.readFile(pkg.scriptPath)
	local scriptInst = roblox.Instance.new("Script")
	scriptInst.Name = pkg.slug
	scriptInst:AddTag("_BatchTest_" .. pkg.slug)
	local ok, err = pcall(function()
		(scriptInst :: any).Source = scriptSource
	end)
	if not ok then
		warn("[CombinePlaces] Cannot set Source on " .. pkg.slug .. ": " .. tostring(err))
		scriptInst:SetAttribute("ScriptSource", scriptSource)
	end
	scriptInst.Parent = batchScriptsFolder
end

-- Also remove any Script instances from the base build's SSS
-- (the batch runner uses loadstring, not auto-executed scripts)
for _, child in sss:GetChildren() do
	if child.ClassName == "Script" and child.Name == "Script" then
		child.Parent = nil
	end
end

-- Serialize and write
local output = roblox.serializePlace(game)
fs.writeFile(outputPath, output)

print("[CombinePlaces] Combined " .. #packages .. " packages into " .. outputPath)
