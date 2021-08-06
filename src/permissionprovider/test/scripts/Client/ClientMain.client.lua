--- Main injection point
-- @script ClientMain
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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