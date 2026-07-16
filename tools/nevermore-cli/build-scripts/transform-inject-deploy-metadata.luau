-- transform-inject-deploy-metadata.luau
-- Injects nevermore deploy metadata into a built place.
--
-- Usage: lune run transform-inject-deploy-metadata.luau <inputPath> <outputPath> <metadataJson>
--
-- The nevermore-cli-manifest package ships a `NevermoreCLIManifestUtils`
-- ModuleScript. This transform finds that module in the built place and writes
-- each key of <metadataJson> onto it as an attribute. At runtime the module
-- reads those attributes back (see NevermoreCLIManifestUtils.getGameMetadata).
--
-- Because the module only exists when the package is installed, a place that
-- does not depend on nevermore-cli-manifest is left unchanged (the output is a
-- faithful copy of the input, so the upload step always has a valid file).

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inputPath = process.args[1]
local outputPath = process.args[2]
local metadataJson = process.args[3]

if not inputPath or not outputPath or not metadataJson then
	print("Usage: lune run transform-inject-deploy-metadata.luau <inputPath> <outputPath> <metadataJson>")
	process.exit(1)
end

-- Keep in sync with the module name shipped by src/nevermore-cli-manifest.
local TARGET_MODULE_NAME = "NevermoreCLIManifestUtils"

local metadata = serde.decode("json", metadataJson)

local contents = fs.readFile(inputPath)
local game = roblox.deserializePlace(contents)

local injected = 0
for _, descendant in game:GetDescendants() do
	if descendant.ClassName == "ModuleScript" and descendant.Name == TARGET_MODULE_NAME then
		for key, value in metadata do
			descendant:SetAttribute(key, value)
		end
		injected += 1
	end
end

if injected == 0 then
	print(string.format("No %q found in place; leaving deploy metadata uninjected", TARGET_MODULE_NAME))
else
	print(string.format("Injected deploy metadata onto %d %q instance(s)", injected, TARGET_MODULE_NAME))
end

local output = roblox.serializePlace(game)
fs.writeFile(outputPath, output)
