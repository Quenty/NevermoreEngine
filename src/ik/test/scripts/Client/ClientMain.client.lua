--- Main injection point
-- @script ClientMain
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("IKServiceClient"))

serviceBag:Init()
serviceBag:Start()

-- Configure
serviceBag:GetService(require("IKServiceClient")):SetLookAround(true)