--!nonstrict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.soundgroup)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.soundgroup) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SoundGroupService"))
serviceBag:Init()
serviceBag:Start()
