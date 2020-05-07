---
-- @module RxInstanceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")

local RxInstanceUtils = {}

function RxInstanceUtils.observeProperty(instance, property)
	assert(typeof(instance) == "Instance")
	assert(type(property) == "string")

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		maid:GiveTask(instance:GetPropertyChangedSignal(property):Connect(function()
			fire(instance[property])
		end))
		fire(instance[property])

		return maid
	end)
end

function RxInstanceUtils.observeChildrenBrio(parent)
	assert(typeof(parent) == "Instance")

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		maid:GiveTask(parent.ChildAdded:Connect(function(child)
			local value = Brio.new(child)
			maid[child] = value
			fire(value)
		end))
		maid:GiveTask(parent.ChildRemoved:Connect(function(child)
			maid[child] = nil
		end))

		for _, child in pairs(parent:GetChildren()) do
			local value = Brio.new(child)
			maid[child] = value
			fire(value)
		end

		return maid
	end)
end

return RxInstanceUtils