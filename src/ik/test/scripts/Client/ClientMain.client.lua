--[[
	@class ClientMain
]]

local require = require(script.Parent.loader).load(script)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("IKServiceClient"))

serviceBag:Init()
serviceBag:Start()

-- Configure
serviceBag:GetService(require("IKServiceClient")):SetLookAround(true)