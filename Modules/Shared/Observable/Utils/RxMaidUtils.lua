---
-- @module RxMaidUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")
local Observable = require("Observable")
local Maid = require("Maid")

local RxMaidUtils = {}

function RxMaidUtils.takeUntilMaidCleaned(maidToObserve)
	assert(maidToObserve)

	local cleaned = false
	maidToObserve:GiveTask(function()
		cleaned = true
	end)

	return function(source)
		if cleaned then
			warn("[RxMaidUtils.takeUntilMaidCleaned] - Maid already cleaned")
			return Rx.EMPTY
		end

		return Observable.new(function(fire, fail, complete)
			if cleaned then
				warn("[RxMaidUtils.takeUntilMaidCleaned] - Maid already cleaned")
				complete()
				return
			end

			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(fire, fail, complete))

			maidToObserve[maid] = complete
			maid:GiveTask(function()
				-- No memory leak!
				maidToObserve[maid] = nil
			end)

			return maid
		end)
	end
end

return RxMaidUtils