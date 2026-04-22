--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.blend)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.blend) then
	return
end
