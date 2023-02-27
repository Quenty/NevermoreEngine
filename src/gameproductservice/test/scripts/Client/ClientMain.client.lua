--[[
	@class ClientMain
]]

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(require(packages.GameProductServiceClient))

serviceBag:Init()
serviceBag:Start()

local GameConfigAssetTypes = require(packages.GameConfigAssetTypes)

local Players = game:GetService("Players")
serviceBag:GetService(require(packages.GameProductServiceClient)):ObservePlayerOwnership(Players.LocalPlayer, GameConfigAssetTypes.PASS, 27825080)
	:Subscribe(function(owns)
		print("owns", owns)
	end)

serviceBag:GetService(require(packages.GameProductServiceClient)):ObservePlayerOwnership(Players.LocalPlayer, GameConfigAssetTypes.ASSET, "FrogOnHead")
	:Subscribe(function(owns)
		print("owns frog on head", owns)
	end)