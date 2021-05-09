---
-- @module RxBinderGroupUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RxBinderGroupUtils = {}
local RxBinderUtils = require("RxBinderUtils")
local Observable = require("Observable")
local Maid = require("Maid")
local Rx = require("Rx")

function RxBinderGroupUtils.observeBinders(binderGroup)
	assert(type(binderGroup) == "table")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(binderGroup.BinderAdded:Connect(function(binder)
			sub:Fire(binder)
		end))

		for _, binder in pairs(binderGroup:GetBinders()) do
			sub:Fire(binder)
		end

		return maid
	end)

end

function RxBinderGroupUtils.observeAllClassesBrio(binderGroup)
	assert(type(binderGroup) == "table")

	return RxBinderGroupUtils.observeBinders(binderGroup)
		:Pipe({
			Rx.flatMap(RxBinderUtils.observeAllBrio)
		})
end

return RxBinderGroupUtils