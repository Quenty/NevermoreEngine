--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("gameconfig"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("GameConfigServiceClient"))

serviceBag:Init()
serviceBag:Start()
