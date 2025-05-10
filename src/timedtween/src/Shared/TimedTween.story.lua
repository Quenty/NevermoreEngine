--[[
	@class TimedTween.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Blend = require("Blend")
local Maid = require("Maid")
local TimedTween = require("TimedTween")

return function(target)
	local maid = Maid.new()

	local timedTween = TimedTween.new(0.3)
	maid:GiveTask(timedTween)

	maid:GiveTask(Blend.mount(target, {
		Blend.New "TextButton" {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = Blend.Computed(timedTween:Observe(), function(position)
				return 1 - position
			end),

			[Blend.OnEvent "Activated"] = function()
				timedTween:Toggle()
			end,
		},
	}))

	return function()
		maid:DoCleaning()
	end
end
