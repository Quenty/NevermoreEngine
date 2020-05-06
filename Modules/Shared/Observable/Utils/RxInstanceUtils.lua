---
-- @module RxInstanceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")
local Observable = require("Observable")
local Maid = require("Maid")

local RxInstanceUtils = {}

function RxInstanceUtils.whereIsAClass(className)
	return Rx.where(function(object)
		return typeof(object) == "Instance" and object:IsA(className)
	end);
end

function RxInstanceUtils.observeChildLeft(child, parent)
	assert(typeof(child) == "Instance")
	assert(typeof(parent) == "Instance")
	assert(child.Parent == parent)

	return Observable.new(function(fire, fail, complete)
		if child.Parent ~= parent then
			fire(true)
			complete()
			return nil
		else
			local maid = Maid.new()
			local completed = false

			maid:GiveTask(child:GetPropertyChangedSignal("Parent"):Connect(function()
				assert(not completed, "Already complete, somehow didn't GC")

				if child.Parent ~= parent then -- Sometimes we get re-entrance
					completed = true
					fire(true)
					complete()
				end
			end))

			return maid
		end
	end)
end

-- Returns children as a stream, initialized with current players
function RxInstanceUtils.observeChildren(parent)
	assert(typeof(parent) == "Instance")

	return Rx.fromSignal(parent.ChildAdded)
		:Pipe({
			Rx.startFrom(function()
				return parent:GetChildren()
			end);
		})
end

function RxInstanceUtils.observeProperty(instance, propertyName)
	assert(typeof(instance) == "Instance")
	assert(type(propertyName) == "string")

	return Rx.fromSignal(instance:GetPropertyChangedSignal(propertyName))
		:Pipe({
			Rx.start(function()
				return instance[propertyName]
			end);
		})
end

return RxInstanceUtils