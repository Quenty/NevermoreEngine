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

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(instance:GetPropertyChangedSignal(property):Connect(function()
			sub:Fire(instance[property])
		end))
		sub:Fire(instance[property])

		return maid
	end)
end

-- Returns a brio of the property value
function RxInstanceUtils.observePropertyBrio(instance, property, predicate)
	assert(typeof(instance) == "Instance")
	assert(type(property) == "string")
	assert(type(predicate) == "function" or predicate == nil)

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handlePropertyChanged()
			maid._property = nil

			local propertyValue = instance[property]
			if not predicate or predicate(propertyValue) then
				local brio = Brio.new(instance[property])
				maid._property = brio
				sub:Fire(brio)
			end
		end

		maid:GiveTask(instance:GetPropertyChangedSignal(property):Connect(handlePropertyChanged))
		handlePropertyChanged()

		return maid
	end)
end

function RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)
	assert(typeof(parent) == "Instance")
	assert(type(className) == "string")
	assert(type(name) == "string")

	return Observable.new(function(sub)
		local topMaid = Maid.new()

		local function handleChild(child)
			if not child:IsA(className) then
				return
			end

			local maid = Maid.new()

			local function handleNameChanged()
				if child.Name == name then
					local brio = Brio.new(child)
					maid._brio = brio
					topMaid._lastBrio = brio

					sub:Fire(brio)
				else
					maid._brio = nil
				end
			end

			maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(handleNameChanged))
			handleNameChanged()

			topMaid[child] = maid
		end

		topMaid:GiveTask(parent.ChildAdded:Connect(handleChild))
		topMaid:GiveTask(parent.ChildRemoved:Connect(function(child)
			topMaid[child] = nil
		end))

		for _, child in pairs(parent:GetChildren()) do
			handleChild(child)
		end

		return topMaid
	end)
end

function RxInstanceUtils.observeChildrenOfClassBrio(parent, className)
	assert(typeof(parent) == "Instance")
	assert(type(className) == "string")

	return RxInstanceUtils.observeChildrenBrio(parent, function(child)
		return child:IsA(className)
	end)
end

function RxInstanceUtils.observeChildrenBrio(parent, predicate)
	assert(typeof(parent) == "Instance")
	assert(type(predicate) == "function" or predicate == nil)

	return Observable.new(function(sub)
		local maid = Maid.new()

		local function handleChild(child)
			if not predicate or predicate(child) then
				local value = Brio.new(child)
				maid[child] = value
				sub:Fire(value)
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

function RxInstanceUtils.observeDescendants(parent, predicate)
	assert(typeof(parent) == "Instance")
	assert(type(predicate) == "function" or predicate == nil)

	return Observable.new(function(sub)
		local maid = Maid.new()
		local added = {}

		local function handleDescendant(child)
			if not predicate or predicate(child) then
				added[child] = true
				sub:Fire(child, true)
			end
		end

		maid:GiveTask(parent.DescendantAdded:Connect(handleDescendant))
		maid:GiveTask(parent.DescendantRemoving:Connect(function(child)
			if added[child] then
				added[child] = nil
				sub:Fire(child, false)
			end
		end))

		for _, descendant in pairs(parent:GetDescendants()) do
			handleDescendant(descendant)
		end

		return maid
	end)
end


return RxInstanceUtils