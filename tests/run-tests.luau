local ServerScriptService = game:GetService("ServerScriptService")
local processServiceExists, ProcessService = pcall(function()
	return game:GetService("ProcessService")
end)

local projectRoot = ServerScriptService.UnitTest

local loader = projectRoot:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(projectRoot)

local Jest = require("Jest")

local status, result = Jest.runCLI(projectRoot, {
	verbose = true,
	ci = false,
}, { projectRoot }):awaitStatus()

if status == "Rejected" then
	print(result)
end

if status == "Resolved" and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	if processServiceExists then
		ProcessService:ExitAsync(0)
	end
end

if processServiceExists then
	ProcessService:ExitAsync(1)
end