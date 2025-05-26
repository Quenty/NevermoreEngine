--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("ik"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
local ikServiceClient = serviceBag:GetService(require("IKServiceClient"))
serviceBag:Init()
serviceBag:Start()

-- Configure
ikServiceClient:SetLookAround(true)
