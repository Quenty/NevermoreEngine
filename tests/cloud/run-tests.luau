local ServerScriptService = game:GetService("ServerScriptService")

local projectRoot = ServerScriptService.UnitTest

print("Bootstrapping game...")
local loader = projectRoot:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(projectRoot)

local Jest = require("Jest")

print("Running tests...\n---")
Jest.runCLI(projectRoot, {
	verbose = true,
	ci = false,
}, { projectRoot }):awaitStatus()