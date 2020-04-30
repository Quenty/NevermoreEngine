--- Utility functions that callback with (maid, value) and guarantee cleanup of maid returning maid
-- @module BoundLinkConnectionUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local BoundLinkConnectionUtils = {}

function BoundLinkConnectionUtils.connectToParent(object, callback)
	assert(typeof(object) == "Instance")
	assert(type(callback) == "function")

	local maid = Maid.new()

	local handleParentChanged = BoundLinkConnectionUtils.makeChangedHandlerWith(maid, callback)
	maid:GiveTask(object:GetPropertyChangedSignal("Parent"):Connect(function()
		handleParentChanged(object.Parent)
	end))
	handleParentChanged(object.Parent)

	return maid
end

function BoundLinkConnectionUtils.connectToParentLinksBoundClass(object, linkName, binder, callback)
	assert(typeof(object) == "Instance")
	assert(type(linkName) == "string")
	assert(binder)
	assert(type(callback) == "function")

	return BoundLinkConnectionUtils.connectToParent(object, function(maid, parent)
		maid:GiveTask(BoundLinkConnectionUtils.connectToLinksValueBoundClass(parent, linkName, binder, callback))
	end)
end

function BoundLinkConnectionUtils.connectToChildren(parent, callback)
	assert(typeof(parent) == "Instance")
	assert(typeof(callback) == "function")

	local topMaid = Maid.new()

	local function handleChildAdded(child)
		if topMaid[child] then
			return -- shouldn't happen, but we'll be paranoid
		end

		local maid = Maid.new()
		topMaid[child] = maid
		callback(topMaid, child)
	end

	topMaid:GiveTask(parent.ChildAdded:Connect(handleChildAdded))
	topMaid:GiveTask(parent.ChildRemoved:Connect(function(child)
		topMaid[child] = nil
	end))

	for _, child in pairs(parent:GetChildren()) do
		handleChildAdded(child)
	end

	return topMaid
end

function BoundLinkConnectionUtils.connectToBoundChildren(parent, binder, callback)
	return BoundLinkConnectionUtils.connectToChildren(parent, function(maid, child)
		maid:GiveTask(BoundLinkConnectionUtils.connectToBoundClass(binder, child, callback))
	end)
end

function BoundLinkConnectionUtils.connectToLinksValueBoundClass(parent, linkName, binder, callback)
	assert(typeof(parent) == "Instance")
	assert(type(linkName) == "string")
	assert(binder)
	assert(type(callback) == "function")

	return BoundLinkConnectionUtils.connectToLinksValue(parent, linkName, function(maid, linkValue)
		maid:GiveTask(BoundLinkConnectionUtils.connectToBoundClass(binder, linkValue, callback))
	end)
end

function BoundLinkConnectionUtils.connectToParentLinks(object, linkName, callback)
	assert(typeof(object) == "Instance")
	assert(type(linkName) == "string")
	assert(type(callback) == "function")

	return BoundLinkConnectionUtils.connectToParent(object, function(maid, parent)
		maid:GiveTask(BoundLinkConnectionUtils.connectToLinksValue(parent, linkName, callback))
	end)
end

function BoundLinkConnectionUtils.connectToLinksValue(parent, linkName, callback)
	assert(typeof(parent) == "Instance")
	assert(type(linkName) == "string")
	assert(typeof(callback) == "function")

	local maid = Maid.new()

	-- So we do assume child name doesn't change
	local function isLink(child)
		return child.Name == linkName and child:IsA("ObjectValue")
	end

	local function handleChildAdded(child)
		if isLink(child) then
			maid[child] = BoundLinkConnectionUtils.connectToLinkValue(child, callback)
		end
	end

	maid:GiveTask(parent.ChildAdded:Connect(handleChildAdded))
	maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		maid[child] = nil
	end))

	for _, child in pairs(parent:GetChildren()) do
		handleChildAdded(child)
	end

	return maid
end

function BoundLinkConnectionUtils.connectToLinkValue(link, callback)
	assert(typeof(link) == "Instance")
	assert(typeof(callback) == "function")

	local maid = Maid.new()

	local handleLinkChanged = BoundLinkConnectionUtils.makeChangedHandlerWith(maid, callback)
	maid:GiveTask(link:GetPropertyChangedSignal("Value"):Connect(function()
		handleLinkChanged(link.Value)
	end))
	handleLinkChanged(link.Value)

	return maid
end

function BoundLinkConnectionUtils.connectToBoundClass(binder, instance, callback)
	assert(binder)
	assert(typeof(instance) == "Instance")
	assert(typeof(callback) == "function")

	local maid = Maid.new()

	local handleClassChanged = BoundLinkConnectionUtils.makeChangedHandlerWith(maid, callback)
	maid:GiveTask(binder:ConnectClassChangedSignal(instance, handleClassChanged))
	handleClassChanged(binder:Get(instance))

	return maid
end

function BoundLinkConnectionUtils.makeChangedHandlerWith(topMaid, callback)
	assert(topMaid)
	assert(type(callback) == "function")

	return function(value, ...)
		if value ~= nil then
			local maid = Maid.new()
			topMaid._callbackMaid = maid
			callback(maid, value, ...)
		else
			topMaid._callbackMaid = nil
		end
	end
end

function BoundLinkConnectionUtils.connectToBoundClasses(binders, instance, callback)
	assert(binders)
	assert(typeof(instance) == "Instance")
	assert(typeof(callback) == "function")

	local maid = Maid.new()

	for _, binder in pairs(binders) do
		maid:GiveTask(BoundLinkConnectionUtils.connectToBoundClass(binder, instance, callback))
	end

	return maid
end

return BoundLinkConnectionUtils