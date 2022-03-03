--[[
	@class ClientMain
]]

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(require(packages.GameProductServiceClient))

serviceBag:Init()
serviceBag:Start()

local Players = game:GetService("Players")
serviceBag:GetService(require(packages.GameProductServiceClient)):ObservePlayerOwnsPass(Players.LocalPlayer, 27825080)
	:Subscribe(function(owns)
		print("owns", owns)
	end)