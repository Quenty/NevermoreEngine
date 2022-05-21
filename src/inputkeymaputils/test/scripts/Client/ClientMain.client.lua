--[[
	@class ClientMain
]]
local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local ContextActionService = game:GetService("ContextActionService")

local INPUT_MODES = require(packages.INPUT_MODES)
local serviceBag = require(packages.ServiceBag).new()

serviceBag:GetService(packages.InputKeyMapServiceClient)
local inputKeyMap = serviceBag:GetService(packages.TestInputKeyMap)

-- Start game
serviceBag:Init()
serviceBag:Start()

local keyMapList = inputKeyMap:GetInputKeyMapList("HONK")

keyMapList:ObserveInputEnumsList():Subscribe(function(...)
	print("activeInputTypes", ...)
	ContextActionService:BindAction("actionTypes", function(_, _, inputObject)
		print("Activated", inputObject.UserInputState)
	end, false, ...)
end)


keyMapList:SetForInputMode(INPUT_MODES.Keypad, { Enum.KeyCode.Space })