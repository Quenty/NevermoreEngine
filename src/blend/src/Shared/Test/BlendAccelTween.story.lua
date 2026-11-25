--!nonstrict
--[[
	@class BlendAccelTween.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local ButtonDragModel = require("ButtonDragModel")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

return function(target)
	local maid = Maid.new()
	local minAcceleration = 0.5
	local maxAcceleration = 12

	local percentTarget = maid:Add(ValueObject.new(0))
	local acceleration = maid:Add(ValueObject.new(1, "number"))
	local dragModel = maid:Add(ButtonDragModel.new())
	dragModel:SetClampWithinButton(true)

	local percentVisible = Blend.AccelTween(percentTarget, acceleration)

	maid:GiveTask(dragModel.DragPositionChanged:Connect(function()
		local position = dragModel:GetDragPosition()
		if position then
			acceleration.Value = minAcceleration + math.clamp(position.X, 0, 1) * (maxAcceleration - minAcceleration)
		end
	end))

	maid:GiveTask((Blend.New "Frame" {
		Name = "BlendAccelTweenStory",
		Size = UDim2.fromOffset(320, 176),
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
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.new(0.9, 0, 0, 32),
				BackgroundColor3 = Color3.fromRGB(214, 220, 227),

				[Blend.Children] = {
					Blend.New "UICorner" {
						CornerRadius = UDim.new(0, 10),
					},
					Blend.New "Frame" {
						AnchorPoint = Vector2.new(0.5, 0.5),
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
			Blend.New "TextLabel" {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.new(1, 0, 0, 20),
				Font = Enum.Font.Gotham,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(79, 85, 92),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = Blend.Computed(acceleration, function(value)
					return string.format("Acceleration %.2f", value)
				end),
			},
			Blend.New "ImageButton" {
				Name = "AccelerationSlider",
				Active = true,
				AutoButtonColor = false,
				Position = UDim2.fromOffset(0, 120),
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = Color3.fromRGB(214, 220, 227),

				[Blend.Instance] = function(inst)
					dragModel:SetButton(inst)
				end,

				[Blend.Children] = {
					Blend.New "UICorner" {
						CornerRadius = UDim.new(0, 10),
					},
					Blend.New "Frame" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = Blend.Computed(acceleration, function(value)
							local alpha = (value - minAcceleration) / (maxAcceleration - minAcceleration)
							return UDim2.fromScale(math.clamp(alpha, 0, 1), 0.5)
						end),
						Size = UDim2.fromOffset(20, 20),
						BackgroundColor3 = Color3.fromRGB(231, 111, 81),

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

	return function()
		maid:DoCleaning()
	end
end
