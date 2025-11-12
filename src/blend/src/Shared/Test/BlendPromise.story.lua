--[[
	@class BlendTextbox.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")
local PlayerThumbnailUtils = require("PlayerThumbnailUtils")

return function(target)
	local maid = Maid.new()

	local userIdState = Instance.new("IntValue")
	userIdState.Value = 4397833
	maid:GiveTask(userIdState)

	local isVisible = Instance.new("BoolValue")
	isVisible.Value = false
	maid:GiveTask(isVisible)

	local userImage = Blend.Dynamic(userIdState, function(userId)
		return PlayerThumbnailUtils.promiseUserThumbnail(userId)
	end)
	local userName = Blend.Dynamic(userIdState, function(userId)
		return PlayerThumbnailUtils.promiseUserName(userId)
	end)
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
		Parent = target,
		Name = "ProfileImage",
		LayoutOrder = 15,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 130),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		[Blend.Children] = {
			Blend.New "UIScale" {
				Scale = Blend.Computed(percentVisible, function(percent)
					return 0.8 + 0.2 * percent
				end),
			},

			Blend.New "TextLabel" {
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				TextTransparency = transparency,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 20,
				Font = Enum.Font.Gotham,
				Text = userName,
			},

			Blend.New "Frame" {
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0.2, 0.25, 0.2),
				BackgroundTransparency = transparency,
				[Blend.Children] = {
					Blend.New "UIAspectRatioConstraint" {
						AspectRatio = 1,
					},
					Blend.New "UICorner" {
						CornerRadius = UDim.new(1, 0),
					},
					Blend.New "UIPadding" {
						PaddingLeft = UDim.new(0, 2),
						PaddingRight = UDim.new(0, 2),
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
					},

					Blend.New "ImageLabel" {
						Size = UDim2.fromScale(1, 1),
						Image = userImage,
						BackgroundTransparency = transparency,
						ImageTransparency = transparency,
						BackgroundColor3 = Color3.new(0.1, 0.1, 0.1),

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

	local PERIOD = 2
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		isVisible.Value = os.clock() / PERIOD % 1 < 0.5
	end))

	local alive = true
	maid:GiveTask(function()
		alive = false
	end)
	maid:GiveTask(isVisible.Changed:Connect(function()
		if not isVisible.Value then
			task.delay(PERIOD / 2, function()
				if alive then
					userIdState.Value = Random.new():NextInteger(1, 1e9)
				end
			end)
		end
	end))

	return function()
		maid:DoCleaning()
	end
end
