--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("snackbar"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SnackbarServiceClient"))
serviceBag:Init()
serviceBag:Start()

local snackbarServiceClient = serviceBag:GetService(require("SnackbarServiceClient"))

local LipsumUtils = require("LipsumUtils")

local function showSnackbar()
	snackbarServiceClient:ShowSnackbar(LipsumUtils.sentence(5), {
		CallToAction = {
			Text = LipsumUtils.word();
			OnClick = function()
				print("Activated action")
			end;
		}
	})
end

showSnackbar()

workspace:WaitForChild("Part").ProximityPrompt.Triggered:Connect(function()
	showSnackbar()
end)
