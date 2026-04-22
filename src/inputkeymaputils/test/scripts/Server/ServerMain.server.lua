--!nonstrict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.inputkeymaputils)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.inputkeymaputils) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("TestInputKeyMap"))
serviceBag:Init()
serviceBag:Start()
