--[[
	@class AnimatedHighlight.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local AnimatedHighlight = require("AnimatedHighlight")
local RxSelectionUtils = require("RxSelectionUtils")

return function(_target)
	local maid = Maid.new()

	maid:GiveTask(RxSelectionUtils.observeFirstAdornee():Subscribe(function(adornee)
		if adornee then
			local renderMaid = Maid.new()

			local animatedHighlight = AnimatedHighlight.new()
			animatedHighlight:SetFillColor(Color3.new(1, 0.5, 0.5))
			animatedHighlight:SetAdornee(adornee)
			animatedHighlight:Show()

			renderMaid:GiveTask(function()
				animatedHighlight:Finish(false, function()
					animatedHighlight:Destroy()
				end)
			end)

			maid._current = renderMaid
		else
			maid._current = nil
		end
	end))

	return function()
		maid:DoCleaning()
	end
end