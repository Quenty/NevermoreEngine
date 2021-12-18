--- Scale ratios for the UI on different devices
-- @module GameScalingUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local GuiService = game:GetService("GuiService")

local RxInstanceUtils = require("RxInstanceUtils")
local Rx = require("Rx")
local Blend = require("Blend")

local GameScalingUtils = {}

function GameScalingUtils.getUIScale(screenAbsoluteSize)
	assert(typeof(screenAbsoluteSize) == "Vector2", "Bad screenAbsoluteSize")
	local smallestAxis = math.min(screenAbsoluteSize.x, screenAbsoluteSize.y)
	local height = screenAbsoluteSize.y

	if GuiService:IsTenFootInterface() then
		return 2
	elseif smallestAxis >= 900 then
		return 1.5
	elseif smallestAxis >= 700 then
		return 1.25
	elseif height >= 500 then
		return 1
	elseif height >= 325 then
		return 0.75
	else
		return 0.6
	end
end

function GameScalingUtils.observeUIScale(screenGui)
	return Blend.Spring(RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize")
		:Pipe({
			Rx.map(GameScalingUtils.getUIScale)
		}), 30)
end

function GameScalingUtils.getDialogPadding(screenAbsoluteSize)
	assert(typeof(screenAbsoluteSize) == "Vector2", "Bad screenAbsoluteSize")
	local smallestAxis = math.min(screenAbsoluteSize.x, screenAbsoluteSize.y)

	if smallestAxis <= 300 then
		return 5
	elseif smallestAxis <= 500 then
		return 10
	elseif smallestAxis <= 700 then
		return 25
	else
		return 50
	end
end

return GameScalingUtils