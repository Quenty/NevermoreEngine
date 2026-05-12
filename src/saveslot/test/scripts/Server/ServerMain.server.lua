--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.saveslot)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SaveSlotService"))
serviceBag:Init()
serviceBag:Start()
