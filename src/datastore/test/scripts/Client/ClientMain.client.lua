--[[
	@class ClientMain
]]

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()

serviceBag:Init()
serviceBag:Start()