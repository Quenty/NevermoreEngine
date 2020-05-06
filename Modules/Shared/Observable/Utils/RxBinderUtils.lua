---
-- @module RxBinderUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Maid = require("Maid")

local RxBinderUtils = {}

function RxBinderUtils.observeBoundClass(binder, instance)
	assert(type(binder) == "table")
	assert(typeof(instance) == "Instance")

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		maid:GiveTask(binder:ObserveInstance(instance, function(class)
			if class then
				fire(class)
			else
				fire(nil)
			end
		end))

		fire(binder:Get(instance))

		return maid
	end)
end

return RxBinderUtils