--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.gameconfig
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

local results = NevermoreTestRunnerUtils.runTestsIfNeededAsync(root)
if results then
	return results
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("GameConfigService"))
serviceBag:GetService(require("TestMantleConfigProvider"))

serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("GameConfigService")):AddProduct("BuyDiamondsProduct", 1235017833)
