--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("UnitTest"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("UnitTestServiceClient"))
serviceBag:Init()
serviceBag:Start()