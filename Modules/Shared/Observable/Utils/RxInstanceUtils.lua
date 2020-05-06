---
-- @module RxInstanceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")

local RxInstanceUtils = {}

function RxInstanceUtils.whereIsAClass(className)
	return Rx.where(function(object)
		return typeof(object) == "Instance" and object:IsA(className)
	end);
end

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