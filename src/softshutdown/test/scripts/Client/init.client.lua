--[[
	@class ClientMain
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local loader = ReplicatedFirst:WaitForChild("_SoftShutdownClientPackages"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SoftShutdownServiceClient"))
serviceBag:Init()
serviceBag:Start()