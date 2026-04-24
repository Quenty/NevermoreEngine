--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService.brine
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")
if NevermoreTestRunnerUtils.runTestsIfNeededAsync(root) then
	return
end

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("BrineService"))
serviceBag:Init()
serviceBag:Start()

local Brine = require("Brine")

local startTime = os.clock()

local serialized, references = Brine.serialize(workspace["Crossroad"])

print(`{(os.clock() - startTime) * 1000} ms to serialize {#serialized} bytes`)

local _deserialized = Brine.deserialize(serialized, references)

print(`{(os.clock() - startTime) * 1000} ms to serialize and deserialize {#serialized} bytes`)
