--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.inputkeymaputils)

local serviceBag = require(packages.ServiceBag).new()

serviceBag:GetService(packages.TestInputKeyMap)

-- Start game
serviceBag:Init()
serviceBag:Start()

