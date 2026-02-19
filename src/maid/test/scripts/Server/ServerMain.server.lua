--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.maid)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.maid) then
	return
end

local Maid = require("Maid")

local maid = Maid.new()

maid:Add(task.defer(function()
	maid:DoCleaning()

	while true do
		task.wait(0.1)
		error("UPDATE (this should never print)")
	end
end))
