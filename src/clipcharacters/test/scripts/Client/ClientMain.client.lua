--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("clipcharacters"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("ClipCharactersServiceClient"))
serviceBag:Init()
serviceBag:Start()

serviceBag:GetService(require("ClipCharactersServiceClient")):PushDisableCharacterCollisionsWithDefault()
