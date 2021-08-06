--- Main injection point
-- @script ServerMain
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("PermissionService"))


serviceBag:Init()

-- local PermissionProviderUtils = require("PermissionProviderUtils")
-- serviceBag:GetService(require("PermissionService"))
-- 	:SetProviderFromConfig(PermissionProviderUtils.createGroupRankConfig({
-- 		groupId = 5;
-- 		minAdminRequiredRank = 256;
-- 		minCreatorRequiredRank = 256;
-- 	}))

serviceBag:Start()