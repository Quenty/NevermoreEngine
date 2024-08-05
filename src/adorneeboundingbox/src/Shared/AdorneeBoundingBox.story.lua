--[[
	@class AdorneeBoundingBox.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local AdorneeBoundingBox = require("AdorneeBoundingBox")
local RxSelectionUtils = require("RxSelectionUtils")
local Rx = require("Rx")
local Draw = require("Draw")

return function(_target)
	local topMaid = Maid.new()

	topMaid:GiveTask(RxSelectionUtils.observeSelectionItemsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local part = brio:GetValue()

		local adorneeBoundingBox = AdorneeBoundingBox.new(part)
		maid:GiveTask(adorneeBoundingBox)

		maid:GiveTask(Rx.combineLatest({
			cframe = adorneeBoundingBox:ObserveCFrame();
			size = adorneeBoundingBox:ObserveSize();
		}):Subscribe(function(state)
			if state.cframe and state.size then
				if state.size == Vector3.zero then
					maid._current = Draw.cframe(state.cframe)
				else
					maid._current = Draw.box(state.cframe, state.size)
				end
			else
				maid._current = nil
			end
		end))
	end))

	return function()
		topMaid:DoCleaning()
	end
end