--[[
	@class ClientMain
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local packages = ReplicatedFirst:WaitForChild("_SoftShutdownClientPackages")

local SoftShutdownServiceClient = require("SoftShutdownServiceClient")
local serviceBag = require("ServiceBag").new()

serviceBag:GetService(SoftShutdownServiceClient)

serviceBag:Init()
serviceBag:Start()