--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService.UnitTest:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.UnitTest)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("UnitTestService"))
serviceBag:Init()
serviceBag:Start()