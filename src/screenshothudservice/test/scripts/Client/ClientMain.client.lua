--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("screenshothudservice"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
local hudService = serviceBag:GetService(require("ScreenshotHudServiceClient"))
serviceBag:Init()
serviceBag:Start()

local Maid = require("Maid")
local ScreenshotHudModel = require("ScreenshotHudModel")

local maid = Maid.new()

local screenshotHudModel = ScreenshotHudModel.new()
screenshotHudModel:SetExperienceNameOverlayEnabled(false)
screenshotHudModel:SetUsernameOverlayEnabled(false)
screenshotHudModel:SetOverlayFont(Enum.Font.FredokaOne)
screenshotHudModel:SetCloseButtonVisible(false)

maid:GiveTask(screenshotHudModel)

maid:GiveTask(hudService:PushModel(screenshotHudModel))

maid:GiveTask(screenshotHudModel.CloseRequested:Connect(function()
	maid:DoCleaning()
end))