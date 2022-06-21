--[[
	@class ClientMain
]]

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(require(packages.DeathReportServiceClient))

serviceBag:Init()
serviceBag:Start()