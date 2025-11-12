--[[
	@class Blend.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	local isVisible = Instance.new("BoolValue")
	isVisible.Value = false

	local percentVisible = Blend.Spring(
		Blend.Computed(isVisible, function(visible)
			return visible and 1 or 0
		end),
		35
	)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	maid:GiveTask((Blend.New "Frame" {
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(0.9, 0.9, 0.9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = transparency,
		Parent = target,

		[Blend.Children] = {
			Blend.New "UIScale" {
				Scale = Blend.Computed(percentVisible, function(percent)
					return 0.8 + 0.2 * percent
				end),
			},
			Blend.New "UICorner" {
				CornerRadius = UDim.new(0.05, 0),
			},
		},
	}):Subscribe())

	local PERIOD = 5
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		isVisible.Value = os.clock() / PERIOD % 1 < 0.5
	end))

	return function()
		maid:DoCleaning()
	end
end
