--!nonstrict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.chatproviderservice)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.chatproviderservice) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("ChatProviderService"))
serviceBag:Init()
serviceBag:Start()
