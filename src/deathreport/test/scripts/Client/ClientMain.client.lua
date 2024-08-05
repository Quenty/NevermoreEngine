--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("deathreport"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("DeathReportServiceClient"))

serviceBag:Init()
serviceBag:Start()