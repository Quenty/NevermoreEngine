--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService["settings-inputkeymap"])

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SettingsInputKeyMapService"))
serviceBag:Init()
serviceBag:Start()
