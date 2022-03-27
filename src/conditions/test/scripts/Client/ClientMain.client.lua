--[[
	@class ClientMain
]]
local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.AimLockServiceClient)

-- Start game
serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(packages.AimLockServiceClient):SetUserControlsEnabled(true)