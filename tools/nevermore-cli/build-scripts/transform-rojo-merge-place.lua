local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local basePlacePath = process.args[1]
local codePlacePath = process.args[2]
local projectFilePath = process.args[3]
local outputPath = process.args[4]

if not basePlacePath or not codePlacePath or not projectFilePath or not outputPath then
	print("Usage: transform-rojo-merge-place <basePlacePath> <codePlacePath> <projectFilePath> <outputPath>")
	process.exit(1)
end

local projectJson = serde.decode("json", fs.readFile(projectFilePath))
local tree = projectJson.tree
if not tree then
	print("Project file missing 'tree' field")
	process.exit(1)
end

local baseContents = fs.readFile(basePlacePath)
local baseGame = roblox.deserializePlace(baseContents)

local codeContents = fs.readFile(codePlacePath)
local codeGame = roblox.deserializePlace(codeContents)

--[[
	Apply $properties from the rojo project onto a base instance.
	This ensures navigation nodes pick up properties like LoadStringEnabled
	that the project file declares but the base place may not have.
]]
local function applyProperties(projectNode: { [string]: any }, baseInstance: Instance)
	local properties = projectNode["$properties"]
	if type(properties) ~= "table" then
		return
	end
	for propName, propValue in properties do
		local ok, err = pcall(function()
			(baseInstance :: any)[propName] = propValue
		end)
		if not ok then
			print(string.format("Warning: could not set %s.%s: %s", baseInstance.Name, propName, tostring(err)))
		end
	end
end

--[[
	Walk the project tree and merge graft points from the code place into the
	base place. A node is a "graft point" if it has $path or $className (excluding
	the root DataModel). Navigation nodes (no $path/$className) are traversed
	without replacing anything — matching how rojo serve works.
]]
local function findAndMerge(projectNode: { [string]: any }, baseParent: Instance, codeParent: Instance)
	for name, value in projectNode do
		if string.sub(name, 1, 1) == "$" then
			continue
		end

		if type(value) ~= "table" then
			continue
		end

		local isGraft = value["$path"] ~= nil or value["$className"] ~= nil
		local baseChild = baseParent:FindFirstChild(name)
		local codeChild = codeParent:FindFirstChild(name)

		if isGraft and codeChild then
			if baseChild then
				baseChild:Destroy()
			end
			codeChild.Parent = baseParent
		elseif not isGraft and baseChild and codeChild then
			findAndMerge(value, baseChild, codeChild)
		elseif not isGraft and baseChild then
			-- Navigation node exists in base but not code — skip, nothing to merge
		elseif isGraft and not codeChild then
			-- Graft point not found in code build — skip
		end
	end
end

-- The root of the tree is the DataModel itself — we navigate its children
-- against the top-level services in both game trees.
for serviceName, serviceNode in tree do
	if string.sub(serviceName, 1, 1) == "$" then
		continue
	end

	if type(serviceNode) ~= "table" then
		continue
	end

	local baseService = baseGame:FindFirstChild(serviceName)
	local codeService = codeGame:FindFirstChild(serviceName)

	if not baseService then
		-- Service doesn't exist in base — if code has it, reparent entirely
		if codeService then
			codeService.Parent = baseGame
		end
		continue
	end

	if not codeService then
		continue
	end

	local isGraft = serviceNode["$path"] ~= nil or serviceNode["$className"] ~= nil
	if isGraft then
		-- Entire service is a graft point — replace it
		baseService:Destroy()
		codeService.Parent = baseGame
	else
		-- Navigate into the service and apply any $properties from the project
		applyProperties(serviceNode, baseService)
		findAndMerge(serviceNode, baseService, codeService)
	end
end

local output = roblox.serializePlace(baseGame)
fs.writeFile(outputPath, output)
