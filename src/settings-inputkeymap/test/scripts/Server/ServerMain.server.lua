--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService["settings-inputkeymap"])

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.SettingsInputKeyMapService)

-- Start game
serviceBag:Init()
serviceBag:Start()
