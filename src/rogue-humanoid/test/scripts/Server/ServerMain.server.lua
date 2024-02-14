--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.roguehumanoid)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("RogueHumanoidService"))
serviceBag:Init()
serviceBag:Start()