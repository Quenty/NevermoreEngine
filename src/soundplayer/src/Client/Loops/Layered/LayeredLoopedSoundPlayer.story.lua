--[[
	@class LayeredLoopedSoundPlayer.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Blend = require("Blend")
local LayeredLoopedSoundPlayer = require("LayeredLoopedSoundPlayer")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	local layeredLoopedSoundPlayer = LayeredLoopedSoundPlayer.new()
	layeredLoopedSoundPlayer:SetSoundParent(target)
	layeredLoopedSoundPlayer:SetBPM(95)
	maid:GiveTask(layeredLoopedSoundPlayer)

	local function initial()
		layeredLoopedSoundPlayer:SwapToChoice("drums", {
			{
				SoundId = "rbxassetid://14478151709",
				Volume = 0.1,
			},
			{
				SoundId = "rbxassetid://14478738244",
				Volume = 0.1,
			},
		})
		layeredLoopedSoundPlayer:SwapToChoice("rifts", {
			{
				SoundId = "rbxassetid://14478152812",
				Volume = 0.2,
			},
			{
				SoundId = "rbxassetid://14478729478",
				Volume = 0.015,
			},
		})
	end
	initial()

	layeredLoopedSoundPlayer:Show()

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
					layeredLoopedSoundPlayer:Toggle()
				end,
			}),

			button({
				Text = "Reset",
				OnActivated = function()
					initial()
				end,
			}),

			button({
				Text = "Combat equip",
				OnActivated = function()
					layeredLoopedSoundPlayer:SwapToChoice("drums", {
						"rbxassetid://14478154829",
						"rbxassetid://14478714545",
						"rbxassetid://14478772830",
						"rbxassetid://14478897865",
					})
					layeredLoopedSoundPlayer:PlayOnceOnLoop("rifts", nil)
				end,
			}),

			button({
				Text = "On target lock",
				OnActivated = function()
					layeredLoopedSoundPlayer:SwapToChoice("drums", {
						{
							SoundId = "rbxassetid://14478150956",
							Volume = 0.1,
						},
						{
							SoundId = "rbxassetid://14478721669",
							Volume = 0.2,
						},
						"rbxassetid://14478154829",
						"rbxassetid://14478764914",
					})

					layeredLoopedSoundPlayer:SwapToChoice("rifts", {
						"rbxassetid://14478145963",
						"rbxassetid://14478156714",
						{
							SoundId = "rbxassetid://14478777472",
							Volume = 0.1,
						},
						{
							SoundId = "rbxassetid://14478793045",
							Volume = 0.1,
						},
					})
				end,
			}),

			button({
				Text = "On low health",
				OnActivated = function()
					layeredLoopedSoundPlayer:SwapToChoice("drums", {
						"rbxassetid://14478746326",
						"rbxassetid://14478767498",
						"rbxassetid://14478797936", -- record scratch
					})
				end,
			}),

			button({
				Text = "Target drop",
				OnActivated = function()
					layeredLoopedSoundPlayer:PlayOnceOnLoop("rifts", "rbxassetid://14478158396")
				end,
			}),
		},
	}))

	return function()
		maid:DoCleaning()
	end
end
