--[[
	@class RadialImage.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local RadialImage = require("RadialImage")

return function(target)
	local maid = Maid.new()

	local radialImage = RadialImage.new()
	radialImage:SetImage("rbxassetid://10049677223")
	radialImage:SetPercent(1)
	radialImage:SetEnabledTransparency(0)
	radialImage:SetDisabledTransparency(0)
	radialImage:SetDisabledColor(Color3.new(0.8, 0.5, 0.5))
	maid:GiveTask(radialImage)

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		radialImage:SetPercent((os.clock()/5) % 1)
	end))

	radialImage.Gui.Parent = target

	return function()
		maid:DoCleaning()
	end
end