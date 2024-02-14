--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("inputkeymaputils"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local ContextActionService = game:GetService("ContextActionService")

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("InputKeyMapServiceClient"))
serviceBag:GetService(require("TestInputKeyMap"))
serviceBag:Init()
serviceBag:Start()

local InputModeTypes = require("InputModeTypes")

local keyMapList = serviceBag:GetService(require("TestInputKeyMap")):GetInputKeyMapList("HONK")

keyMapList:ObserveInputEnumsList():Subscribe(function(...)
	print("activeInputTypes", ...)
	ContextActionService:BindAction("actionTypes", function(_, _, inputObject)
		print("Activated", inputObject.UserInputState)
	end, false, ...)
end)


keyMapList:SetForInputMode(InputModeTypes.Keypad, { Enum.KeyCode.Space })