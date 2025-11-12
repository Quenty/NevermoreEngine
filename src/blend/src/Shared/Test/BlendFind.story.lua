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

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = Color3.new(0.9, 0.9, 0.9)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = transparency
	frame.Parent = target
	maid:GiveTask(frame)

	local subFrame = Instance.new("Frame")
	subFrame.Name = "CenterFrame"
	subFrame.Size = UDim2.fromScale(0.5, 0.5)
	subFrame.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
	subFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	subFrame.Position = UDim2.fromScale(0.5, 0.5)
	subFrame.BackgroundTransparency = transparency
	subFrame.Parent = frame

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "MyUIScale"
	uiScale.Parent = subFrame

	maid:GiveTask(Blend.mount(frame, {
		Size = UDim2.fromScale(0.5, 0.5),

		Blend.New "UICorner" {
			CornerRadius = UDim.new(0.05, 0),
		},

		Blend.Find "Frame" {
			Name = "CenterFrame",

			Blend.Find "UIScale" {
				Name = "MyUIScale",

				Scale = Blend.Computed(percentVisible, function(percent)
					return 0.8 + 0.2 * percent
				end),
			},

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0.05, 0),
			},
		},
	}))

	local PERIOD = 2
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		isVisible.Value = os.clock() / PERIOD % 1 < 0.5
	end))

	return function()
		maid:DoCleaning()
	end
end
