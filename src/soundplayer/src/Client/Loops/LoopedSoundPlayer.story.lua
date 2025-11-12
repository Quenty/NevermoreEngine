--[[
	@class LoopedSoundPlayer.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Blend = require("Blend")
local LoopedSoundPlayer = require("LoopedSoundPlayer")
local LoopedSoundScheduleUtils = require("LoopedSoundScheduleUtils")
local Maid = require("Maid")
local RandomUtils = require("RandomUtils")

return function(target)
	local maid = Maid.new()

	local ORIGINAL = nil --"rbxassetid://14477435416"

	local loopedSoundPlayer = maid:Add(LoopedSoundPlayer.new(ORIGINAL, target))
	loopedSoundPlayer:SetDoSyncSoundPlayback(true)
	loopedSoundPlayer:SetCrossFadeTime(2)
	loopedSoundPlayer:SetVolumeMultiplier(0.25)
	loopedSoundPlayer:SetSoundParent(target)

	local OPTIONS = {
		"rbxassetid://14477453689",
	}

	maid:GiveTask(task.spawn(function()
		while true do
			task.wait(2)
			-- loopedSoundPlayer:Swap(RandomUtils.choice(OPTIONS))
		end
	end))

	loopedSoundPlayer:Show()

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
					loopedSoundPlayer:Toggle()
				end,
			}),

			button({
				Text = "Reset",
				OnActivated = function()
					loopedSoundPlayer:Swap(ORIGINAL)
				end,
			}),

			button({
				Text = "Swap sample",
				OnActivated = function()
					loopedSoundPlayer:SwapToSamples({
						"rbxassetid://14478670277",
						"rbxassetid://14478671494",
						"rbxassetid://14478672676",
					})
				end,
			}),

			button({
				Text = "Play once",
				OnActivated = function()
					loopedSoundPlayer:PlayOnce("rbxassetid://14478764914")
				end,
			}),

			button({
				Text = "Play delayed loop",
				OnActivated = function()
					loopedSoundPlayer:Swap(
						{
							SoundId = "rbxassetid://6052547865",
							Volume = 3,
						},
						LoopedSoundScheduleUtils.schedule({
							loopDelay = NumberRange.new(0.25, 1),
						})
					)
				end,
			}),

			button({
				Text = "Swap on loop",
				OnActivated = function()
					loopedSoundPlayer:SwapOnLoop(RandomUtils.choice(OPTIONS))
				end,
			}),
		},
	}))

	return function()
		maid:DoCleaning()
	end
end
