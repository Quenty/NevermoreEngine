--!nonstrict
--[[
	@class BlendAccelTween.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

return function(target)
	local maid = Maid.new()

	local percentTarget = ValueObject.new(0)

	local percentVisible = Blend.AccelTween(percentTarget, 1)

	maid:GiveTask((Blend.New "Frame" {
		Name = "BlendAccelTweenStory",
		Size = UDim2.fromOffset(320, 120),
		BackgroundColor3 = Color3.fromRGB(235, 238, 242),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = target,

		[Blend.Children] = {
			Blend.New "UICorner" {
				CornerRadius = UDim.new(0, 12),
			},
			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			},
			Blend.New "TextLabel" {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Font = Enum.Font.GothamMedium,
				TextSize = 18,
				TextColor3 = Color3.fromRGB(35, 37, 41),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = Blend.Computed(percentVisible, function(percent)
					return string.format("Blend.AccelTween %.2f", percent)
				end),
			},
			Blend.New "Frame" {
				Position = UDim2.new(0, 0, 0, 44),
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = Color3.fromRGB(214, 220, 227),

				[Blend.Children] = {
					Blend.New "UICorner" {
						CornerRadius = UDim.new(0, 10),
					},
					Blend.New "Frame" {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = Blend.Computed(percentVisible, function(percent)
							return UDim2.fromScale(math.clamp(percent, 0, 1), 0.5)
						end),
						Size = UDim2.fromOffset(28, 28),
						BackgroundColor3 = Color3.fromRGB(42, 157, 143),

						[Blend.Children] = {
							Blend.New "UICorner" {
								CornerRadius = UDim.new(1, 0),
							},
						},
					},
				},
			},
		},
	}):Subscribe())

	local period = 4
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		percentTarget.Value = os.clock() / period % 1 < 0.5 and 1 or 0
	end))

	maid:GiveTask(percentTarget)

	return function()
		maid:DoCleaning()
	end
end
