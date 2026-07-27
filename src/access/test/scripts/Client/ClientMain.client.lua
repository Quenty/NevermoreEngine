--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("access"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("AccessServiceClient"))
serviceBag:Init()
serviceBag:Start()