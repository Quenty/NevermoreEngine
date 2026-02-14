--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.screenshothudservice)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.screenshothudservice)
