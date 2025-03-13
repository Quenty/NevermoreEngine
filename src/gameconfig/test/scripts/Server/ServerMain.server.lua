--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.gameconfig)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("GameConfigService"))
serviceBag:GetService(require("TestMantleConfigProvider"))

serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("GameConfigService")):AddProduct("BuyDiamondsProduct", 1235017833)
