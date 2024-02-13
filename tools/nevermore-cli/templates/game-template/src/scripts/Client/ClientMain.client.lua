--[[
	@class ClientMain
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local loader = ReplicatedStorage:WaitForChild("{{gameNameProper}}"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()

serviceBag:GetService(require("{{gameNameProper}}ServiceClient"))

serviceBag:Init()
serviceBag:Start()