--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService.{{gameNameProper}}:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.{{gameNameProper}})

local serviceBag = require("ServiceBag").new()

serviceBag:GetService(require("{{gameNameProper}}Service"))

serviceBag:Init()
serviceBag:Start()