---
-- @module RxInstanceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Rx = require("Rx")
local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local RxBrioUtils = require("RxBrioUtils")

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

function RxInstanceUtils.observeValidPropertyBrio(instance, property, predicate)
	assert(typeof(instance) == "Instance")
	assert(type(property) == "string")
	assert(type(predicate) == "function" or predicate == nil)

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		local function handlePropertyChanged()
			maid._property = nil

			local propertyValue = instance[property]
			if not predicate or predicate(propertyValue) then
				local brio = Brio.new(instance[property])
				maid._property = brio
				fire(brio)
			end
		end

		maid:GiveTask(instance:GetPropertyChangedSignal(property):Connect(handlePropertyChanged))
		handlePropertyChanged()

		return maid
	end)
end

function RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
	assert(parent)
	assert(className)
	assert(name)

	return RxInstanceUtils.observeChildrenBrio(parent, function(child)
		return child:IsA(className)
	end):Pipe({
		Rx.switchMap(RxBrioUtils.mapBrio(function(child)
			return RxInstanceUtils.observeValidPropertyBrio(child, "Name", function(childName)
				return childName == name
			end)
		end));
	})
end


-- FIres once, and then completes
function RxInstanceUtils.observeParentChangeFrom(child, parent)
	assert(child)
	assert(parent)
	assert(child.Parent == parent)

	return Observable.new(function(fire, fail, complete)
		if child.Parent ~= parent then
			fire()
			complete()
			return
		end

		local maid = Maid.new()

		maid:GiveTask(child:GetPropertyChangedSignal("Parent"):Connect(function()
			if child.Parent ~= parent then
				fire()
				complete()
			end
		end))

		return maid
	end)
end

function RxInstanceUtils.observeChildrenBrio(parent, predicate)
	assert(typeof(parent) == "Instance")
	assert(type(predicate) == "function" or predicate == nil)

	return Observable.new(function(fire, fail, complete)
		local maid = Maid.new()

		local function handleChild(child)
			if not predicate or predicate(child) then
				local value = Brio.new(child)
				maid[child] = value
				fire(value)
			end
		end

		maid:GiveTask(parent.ChildAdded:Connect(handleChild))
		maid:GiveTask(parent.ChildRemoved:Connect(function(child)
			maid[child] = nil
		end))

		for _, child in pairs(parent:GetChildren()) do
			handleChild(child)
		end

		return maid
	end)
end

return RxInstanceUtils