--[[
	@class AnimatedHighlight.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local AnimatedHighlightGroup = require("AnimatedHighlightGroup")
local RxSelectionUtils = require("RxSelectionUtils")

return function(_target)
	local maid = Maid.new()

	local animatedHighlightGroup = AnimatedHighlightGroup.new()
	animatedHighlightGroup:SetDefaultFillColor(Color3.new(0.5, 1, 0.5))
	animatedHighlightGroup:SetDefaultSpeed(5)
	animatedHighlightGroup:SetDefaultHighlightDepthMode(Enum.HighlightDepthMode.Occluded)
	maid:GiveTask(animatedHighlightGroup)

	maid:GiveTask(RxSelectionUtils.observeAdorneesBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local adorneeMaid = brio:ToMaid()
		local adornee = brio:GetValue()

		local highlight = animatedHighlightGroup:Highlight(adornee)

		local color = BrickColor.random().Color

		highlight:SetFillColor(color)
		highlight:SetOutlineColor(color)

		adorneeMaid:GiveTask(highlight)
	end))

	return function()
		maid:DoCleaning()
	end
end