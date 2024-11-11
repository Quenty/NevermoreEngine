--[[
	@class RadialImage.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local RadialImage = require("RadialImage")

return function(target)
	local maid = Maid.new()

	local radialImage = RadialImage.new()
	radialImage:SetImage("rbxassetid://10598010378")
	radialImage:SetPercent(0.25)
	radialImage:SetEnabledTransparency(0)
	radialImage:SetDisabledTransparency(0)
	radialImage:SetDisabledColor(Color3.new(0.8, 0.5, 0.5))
	maid:GiveTask(radialImage)

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		-- radialImage:SetPercent((os.clock()/5) % 1)

		local scale = (1 + math.sin((os.clock()/5)*math.pi*2))/2
		radialImage.Gui.Size = UDim2.fromOffset(math.round(scale*90), math.round(scale*90))
	end))

	radialImage.Gui.Parent = target

	return function()
		maid:DoCleaning()
	end
end