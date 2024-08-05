--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.inputkeymaputils)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("TestInputKeyMap"))
serviceBag:Init()
serviceBag:Start()

