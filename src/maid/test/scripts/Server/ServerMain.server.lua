--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.maid
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(root) then
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
