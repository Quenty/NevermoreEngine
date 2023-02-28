--[[
	@class ClientMain
]]
local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
local hudService = serviceBag:GetService(packages.ScreenshotHudServiceClient)

-- Start game
serviceBag:Init()
serviceBag:Start()

local Maid = require(packages.Maid)
local ScreenshotHudModel = require(packages.ScreenshotHudModel)

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