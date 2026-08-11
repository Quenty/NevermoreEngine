--!nonstrict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.inputkeymaputils
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

local results = NevermoreTestRunnerUtils.runTestsIfNeededAsync(root)
if results then
	return results
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("TestInputKeyMap"))
serviceBag:Init()
serviceBag:Start()
