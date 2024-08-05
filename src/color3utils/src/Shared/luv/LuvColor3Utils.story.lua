--[[
	@class LuvColor3Utils.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local LuvColor3Utils = require("LuvColor3Utils")

return function(target)
	local maid = Maid.new()

	local start = Color3.fromRGB(184, 127, 100)
	local finish = Color3.fromRGB(16, 60, 76)

	for i=0, 100 do
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = LuvColor3Utils.lerp(start, finish, i/100)
		frame.Size = UDim2.fromScale(1/(100 + 1), 0.5)
		frame.Position = UDim2.fromScale(i/(100 + 1), 0)
		frame.BorderSizePixel = 0
		frame.Parent = target
		maid:GiveTask(frame)
	end

	for i=0, 100 do
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = start:Lerp(finish, i/100)
		frame.Size = UDim2.fromScale(1/(100 + 1), 0.5)
		frame.Position = UDim2.fromScale(i/(100 + 1), 0.5)
		frame.BorderSizePixel = 0
		frame.Parent = target
		maid:GiveTask(frame)
	end

	return function()
		maid:DoCleaning()
	end
end