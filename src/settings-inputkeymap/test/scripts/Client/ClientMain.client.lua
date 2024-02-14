--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("settings-inputkeymap"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SettingsInputKeyMapServiceClient"))
serviceBag:Init()
serviceBag:Start()

local InputKeyMapList = require("InputKeyMapList")
local InputModeTypes = require("InputModeTypes")
local InputKeyMap = require("InputKeyMap")
local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")

local inputKeyMapList = InputKeyMapList.new("JUMP", {
	InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.Q });
	InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonY });
	InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary3") });
}, {
	bindingName = "Jump";
	rebindable = true;
})

serviceBag:GetService(require("SettingsInputKeyMapServiceClient")):AddInputKeyMapList(inputKeyMapList)