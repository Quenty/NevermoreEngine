--[[
	@class InfluxDBClient.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local InfluxDBClient = require("InfluxDBClient")
local InfluxDBClientConfigUtils = require("InfluxDBClientConfigUtils")
local InfluxDBPoint = require("InfluxDBPoint")
local Maid = require("Maid")

return function(_target)
	local maid = Maid.new()

	local config = InfluxDBClientConfigUtils.createClientConfig({
		url = "https://ingest.robloxanalytics.com/";
		token = "test-api-key";
	})

	local influxDBClient = InfluxDBClient.new(config)
	maid:GiveTask(function()
		influxDBClient:PromiseFlushAll():Finally(function()
			influxDBClient:Destroy()
		end)
	end)

	local writeAPI = influxDBClient:GetWriteAPI("studio-koi-koi", "initial-bucket")
	writeAPI:SetPrintDebugWriteEnabled(true)

	local point = InfluxDBPoint.new("test")
	point:AddTag("game_name", "boxing")
	point:AddTag("game_id", tostring(game.GameId))
	point:AddTag("place_id", tostring(game.PlaceId))
	point:AddStringField("username", "Quenty")
	point:AddIntField("userid", 4397833)
	point:AddFloatField("fps", 30 + math.random()*30)
	point:AddBooleanField("is_alive", true)
	point:AddBooleanField("is_silent", false)

	writeAPI:QueuePoint(point)

	maid:GiveTask(writeAPI.RequestFinished:Connect(function(response)
		print("Got response", response)
	end))

	writeAPI:PromiseFlush()

	return function()
		maid:DoCleaning()
	end
end