--- Main injection point
-- @script ClientMain
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("CmdrServiceClient"))

serviceBag:Init()
serviceBag:Start()