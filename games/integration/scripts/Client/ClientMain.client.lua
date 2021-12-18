--- Main injection point
-- @script ClientMain
-- @author Quenty

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.GameServiceClient)
serviceBag:Init()
serviceBag:Start()

