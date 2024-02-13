--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("permissionprovider"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("PermissionServiceClient"))
serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("PermissionServiceClient")):PromisePermissionProvider()
	:Then(function(permissionProvider)
		return permissionProvider:PromiseIsAdmin()
	end)
	:Then(function(isAdmin)
		print("isAdmin", isAdmin)
	end)

print("Loaded")