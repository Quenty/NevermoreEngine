--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("datastore"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()

serviceBag:Init()
serviceBag:Start()