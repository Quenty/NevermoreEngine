--[[
	@class ClientMain
]]
local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.SettingsInputKeyMapServiceClient)

-- Start game
serviceBag:Init()
serviceBag:Start()

local InputKeyMapList = require(packages.InputKeyMapList)
local InputModeTypes = require(packages.InputModeTypes)
local InputKeyMap = require(packages.InputKeyMap)
local SlottedTouchButtonUtils = require(packages.SlottedTouchButtonUtils)

local inputKeyMapList = InputKeyMapList.new("JUMP", {
	InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.Q });
	InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonY });
	InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary3") });
}, {
	bindingName = "Jump";
	rebindable = true;
})

serviceBag:GetService(packages.SettingsInputKeyMapServiceClient):AddInputKeyMapList(inputKeyMapList)