--!nonstrict
--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("teleportserviceutils"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("TeleportDataServiceClient"))
serviceBag:Init()
serviceBag:Start()
