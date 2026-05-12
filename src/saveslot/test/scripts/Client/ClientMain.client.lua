--!nonstrict
--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("saveslot"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SaveSlotServiceClient"))
serviceBag:Init()
serviceBag:Start()
