--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.{{packageName}})

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.{{packageNameProper}}Service)

-- Start game
serviceBag:Init()
serviceBag:Start()