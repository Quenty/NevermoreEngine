--!nonstrict
--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("genericscreenguiprovider"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("ScreenGuiService"))
serviceBag:Init()
serviceBag:Start()
