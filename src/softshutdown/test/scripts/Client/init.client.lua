--[[
	@class ClientMain
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local packages = ReplicatedFirst:WaitForChild("_SoftShutdownClientPackages")

local SoftShutdownServiceClient = require(packages.SoftShutdownServiceClient)
local serviceBag = require(packages.ServiceBag).new()

serviceBag:GetService(SoftShutdownServiceClient)

serviceBag:Init()
serviceBag:Start()