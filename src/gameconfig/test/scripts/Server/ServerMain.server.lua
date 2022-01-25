--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.gameconfig)

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.GameConfigService)
serviceBag:GetService(packages.TestMantleConfigProvider)

serviceBag:Init()
serviceBag:Start()

