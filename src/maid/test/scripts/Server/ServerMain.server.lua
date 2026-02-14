--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.maid)

local Maid = require("Maid")
local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

local maid = Maid.new()

maid:Add(task.defer(function()
	maid:DoCleaning()

	while true do
		task.wait(0.1)
		error("UPDATE (this should never print)")
	end
end))

NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.maid)
