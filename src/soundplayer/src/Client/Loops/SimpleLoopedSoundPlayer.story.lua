--[[
	@class SimpleLoopedSoundPlayer.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Blend = require("Blend")
local Maid = require("Maid")
local SimpleLoopedSoundPlayer = require("SimpleLoopedSoundPlayer")

return function(target)
	local maid = Maid.new()

	local simpleLoopedSoundPlayer = maid:Add(SimpleLoopedSoundPlayer.new("rbxassetid://14477453689"))
	simpleLoopedSoundPlayer:SetTransitionTime(1)

	simpleLoopedSoundPlayer.Sound.Parent = target

	simpleLoopedSoundPlayer:Show()

	local function button(props)
		return Blend.New "TextButton" {
			Text = props.Text,
			AutoButtonColor = true,
			Font = Enum.Font.FredokaOne,
			Size = UDim2.fromOffset(100, 30),

			Blend.New "UICorner" {},

			[Blend.OnEvent "Activated"] = function()
				props.OnActivated()
			end,
		}
	end

	maid:GiveTask(Blend.mount(target, {
		Blend.New "Frame" {
			Name = "ButtonContainer",
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 5),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(1, 0, 0, 30),

			Blend.New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 5),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			},

			button({
				Text = "Toggle",
				OnActivated = function()
					simpleLoopedSoundPlayer:Toggle()
				end,
			}),
		},
	}))

	return function()
		maid:DoCleaning()
	end
end
