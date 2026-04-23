--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.gameconfig
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(root) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("GameConfigService"))
serviceBag:GetService(require("TestMantleConfigProvider"))

serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("GameConfigService")):AddProduct("BuyDiamondsProduct", 1235017833)
