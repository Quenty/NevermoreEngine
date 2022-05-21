--[[
	@class ClientMain
]]

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
local ikServiceClient = serviceBag:GetService(packages.IKServiceClient)

serviceBag:Init()
serviceBag:Start()

-- Configure
ikServiceClient:SetLookAround(true)