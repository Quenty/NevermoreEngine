--[[
	@class ClientMain
]]

local loader = game:GetService("ReplicatedStorage"):WaitForChild("gameproductservice"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("GameProductServiceClient"))

serviceBag:Init()
serviceBag:Start()

local GameConfigAssetTypes = require("GameConfigAssetTypes")

local Players = game:GetService("Players")
serviceBag:GetService(require("GameProductServiceClient")):ObservePlayerOwnership(Players.LocalPlayer, GameConfigAssetTypes.PASS, 27825080)
	:Subscribe(function(owns)
		print("owns", owns)
	end)

serviceBag:GetService(require("GameProductServiceClient")):ObservePlayerOwnership(Players.LocalPlayer, GameConfigAssetTypes.ASSET, "FrogOnHead")
	:Subscribe(function(owns)
		print("owns frog on head", owns)
	end)