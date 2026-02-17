--!nonstrict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.clipcharacters)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("ClipCharactersService"))
serviceBag:Init()
serviceBag:Start()

NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.clipcharacters)
