--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.robloxapidump)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.robloxapidump) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("RobloxApiDumpService"))
serviceBag:Init()
serviceBag:Start()
