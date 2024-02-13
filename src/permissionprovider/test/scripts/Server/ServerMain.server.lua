--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.permissionprovider)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("PermissionService"))

serviceBag:Init()
serviceBag:Start()
