local ServerScriptService = game:GetService("ServerScriptService")

local projectRoot = ServerScriptService.UnitTest

print("Bootstrapping game...")
local loader = projectRoot:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(projectRoot)

local Jest = require("Jest")

print("Running tests...\n---")
local status, result = Jest.runCLI(projectRoot, {
	verbose = true,
	ci = false,
}, { projectRoot }):awaitStatus()

if status == "Rejected" then
	print("Tests failed:")
	print(result)
end

if status == "Resolved" and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	print("Tests passed!")
end