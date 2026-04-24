--!strict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.{{gameNameProper}}
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("{{gameNameProper}}Service"))
serviceBag:Init()
serviceBag:Start()
