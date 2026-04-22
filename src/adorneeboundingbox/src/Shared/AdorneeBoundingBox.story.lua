--!nonstrict
--[[
	@class AdorneeBoundingBox.story
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local AdorneeBoundingBox = require("AdorneeBoundingBox")
local Draw = require("Draw")
local Maid = require("Maid")
local Rx = require("Rx")
local RxSelectionUtils = require("RxSelectionUtils")

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
			cframe = adorneeBoundingBox:ObserveCFrame(),
			size = adorneeBoundingBox:ObserveSize(),
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
