--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.influxdbclient)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

require("InfluxDBClient")

NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.influxdbclient)
