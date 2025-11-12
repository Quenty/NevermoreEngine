--[[
	@class Blend.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

return function(target)
	local maid = Maid.new()

	local percentVisible = Blend.State(0)
	local state = Blend.State("a")
	maid:GiveTask(state)

	local uiCornerValueObject = ValueObject.new()
	uiCornerValueObject.Value = Blend.New "UICorner" {
		CornerRadius = UDim.new(0, 5),
	}
	maid:GiveTask(uiCornerValueObject)

	-- Reassign to a new value
	maid:GiveTask(task.delay(1, function()
		uiCornerValueObject.Value = Blend.New "UICorner" {
			CornerRadius = UDim.new(0, 5),
		}
	end))

	local transparency = Blend.Computed(percentVisible, function(visible)
		return 1 - visible
	end)

	-- Try a kitchen sink of items
	maid:GiveTask((Blend.New "TextLabel" {
		Parent = target,
		Font = Enum.Font.FredokaOne,
		Size = Blend.Computed(percentVisible, function(visible)
			return UDim2.fromOffset(visible * 100 + 50, 50)
		end),
		TextTransparency = transparency,
		BackgroundTransparency = transparency,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = state,
		TextSize = 15,
		TextScaled = false,

		[Blend.Children] = {
			Blend.New "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			},

			Blend.New "UIScale" {
				Scale = Blend.Computed(percentVisible, function(visible)
					return 0.8 + 0.2 * visible
				end),
			},

			uiCornerValueObject,

			Rx.NEVER,
			Rx.EMPTY,

			{
				Blend.Single(Blend.Computed(percentVisible, function(visible)
					if visible <= 0.5 then
						return nil
					else
						return Blend.New "Frame" {
							Size = UDim2.fromOffset(150, 30),
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 1, 10),
							BackgroundTransparency = transparency,

							Blend.New "UICorner" {
								CornerRadius = UDim.new(0, 10),
							},
						}
					end
				end)),
			},

			{
				Blend.Single(Blend.Computed(percentVisible, function(visible)
					local results = {}

					-- constructs a ton of children everytime this changes
					for x = 0, visible * 100, 20 do
						table.insert(
							results,
							Blend.New "Frame" {
								Size = UDim2.fromOffset(8, 8),
								Position = UDim2.fromScale(x / 100, 0.9),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BorderSizePixel = 0,
								BackgroundColor3 = Color3.new(x / 100, 0.5, 0.5),
								BackgroundTransparency = transparency,

								[Blend.Children] = {
									Blend.New "UICorner" {
										CornerRadius = UDim.new(0, 10),
									},
								},
							}
						)
					end

					return results
				end)),
			},
		},
	}):Subscribe())

	local PERIOD = 5
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		local timeElapsed = os.clock()
		state.Value = string.format(
			"%02d:%02d:%0.3d",
			math.floor(timeElapsed / 60) % 60,
			math.floor(timeElapsed % 60),
			math.floor(timeElapsed * 1000) % 1000
		)
		percentVisible.Value = math.clamp((math.sin(os.clock() * math.pi * 2 / PERIOD) + 1), 0, 1)
	end))

	return function()
		maid:DoCleaning()
	end
end
