--!nonstrict
--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.permissionprovider
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(root) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("PermissionService"))

serviceBag:Init()
serviceBag:Start()
