--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.deathreport)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("DeathReportService"))

serviceBag:Init()
serviceBag:Start()

