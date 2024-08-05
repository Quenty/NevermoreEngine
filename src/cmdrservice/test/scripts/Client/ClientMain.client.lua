--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("cmdrservice"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("CmdrServiceClient"))

serviceBag:Init()
serviceBag:Start()