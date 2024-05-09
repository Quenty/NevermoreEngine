--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.snackbar)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SnackbarService"))
serviceBag:Init()
serviceBag:Start()