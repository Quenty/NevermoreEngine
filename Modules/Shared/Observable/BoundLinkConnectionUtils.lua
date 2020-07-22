--- Utility functions that callback with (maid, value) and guarantee cleanup of maid returning maid
-- @module BoundLinkConnectionUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local observeProperty = require("observeProperty")
local CharacterUtils = require("CharacterUtils")

local BoundLinkConnectionUtils = {}

-- TODO: Move this somewhere else? (ConnectionUtils?)
function BoundLinkConnectionUtils.connectToParent(object, callback)
	assert(typeof(object) == "Instance", "Bad 'object' instance")
	assert(type(callback) == "function", "Bad 'callback' function")

	return observeProperty(object, "Parent", callback)
end

function BoundLinkConnectionUtils.connectToParentLinksBoundClass(object, linkName, binder, callback)
	assert(typeof(object) == "Instance", "Bad 'object' instance")
	assert(type(linkName) == "string", "Bad 'linkName' string")
	assert(binder, "Bad 'binder' binder")
	assert(type(callback) == "function", "Bad 'callback' function")

	return BoundLinkConnectionUtils.connectToParent(object, function(maid, parent)
		maid:GiveTask(BoundLinkConnectionUtils.connectToLinksValueBoundClass(parent, linkName, binder, callback))
	end)
end

function BoundLinkConnectionUtils.connectToGetPlayerFromCharacter(object, callback)
	assert(typeof(object) == "Instance", "Bad 'object' instance")
	assert(type(callback) == "function", "Bad 'callback' function")

	local maid = Maid.new()

	-- Assume character doesn't change after being assigned (i.e. ancestry is aligned with setting)

	local handleChanged = BoundLinkConnectionUtils._makeChangedHandlerWithNoCheck(maid, callback)
	maid:GiveTask(object.AncestryChanged:Connect(function()
		handleChanged(CharacterUtils.getPlayerFromCharacter(object))
	end))
	handleChanged(CharacterUtils.getPlayerFromCharacter(object))

	return maid
end

function BoundLinkConnectionUtils.connectToChildren(parent, callback)
	assert(typeof(parent) == "Instance", "Bad 'parent' instance")
	assert(typeof(callback) == "function", "Bad 'callback' function")

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
	assert(typeof(parent) == "Instance", "Bad 'parent' instance")
	assert(binder, "Bad 'binder' binder")
	assert(type(callback) == "function", "Bad 'callback' instance")

	return BoundLinkConnectionUtils.connectToChildren(parent, function(maid, child)
		maid:GiveTask(BoundLinkConnectionUtils.connectToBoundClass(binder, child, callback))
	end)
end

function BoundLinkConnectionUtils.connectToLinksValueBoundClass(parent, linkName, binder, callback)
	assert(typeof(parent) == "Instance", "Bad 'parent' instance")
	assert(type(linkName) == "string", "Bad 'linkName' string")
	assert(binder, "Bad 'binder' binder")
	assert(type(callback) == "function", "Bad 'callback' instance")

	return BoundLinkConnectionUtils.connectToLinksValue(parent, linkName, function(maid, linkValue)
		maid:GiveTask(BoundLinkConnectionUtils.connectToBoundClass(binder, linkValue, callback))
	end)
end

function BoundLinkConnectionUtils.connectToParentLinks(object, linkName, callback)
	assert(typeof(object) == "Instance", "Bad 'object' instance")
	assert(type(linkName) == "string", "Bad 'linkName' name")
	assert(type(callback) == "function", "Bad 'callback' function")

	return BoundLinkConnectionUtils.connectToParent(object, function(maid, parent)
		maid:GiveTask(BoundLinkConnectionUtils.connectToLinksValue(parent, linkName, callback))
	end)
end

-- @param callback callback(maid, linkValue, link)
function BoundLinkConnectionUtils.connectToLinksValue(parent, linkName, callback)
	assert(typeof(parent) == "Instance", "Bad 'parent' instance")
	assert(type(linkName) == "string", "Bad 'linkName' instance")
	assert(typeof(callback) == "function", "Bad 'callback' function")

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
	assert(typeof(link) == "Instance", "Bad 'link' instance")
	assert(typeof(callback) == "function", "Bad 'callback' function")

	local maid = Maid.new()

	local handleLinkChanged = BoundLinkConnectionUtils._makeChangedHandlerWith(maid, callback)
	maid:GiveTask(link:GetPropertyChangedSignal("Value"):Connect(function()
		handleLinkChanged(link.Value, link)
	end))
	handleLinkChanged(link.Value, link)

	return maid
end

function BoundLinkConnectionUtils.connectToBoundClass(binder, instance, callback)
	assert(binder, "Bad 'binder' binder")
	assert(typeof(instance) == "Instance", "Bad 'instance' instance")
	assert(typeof(callback) == "function", "Bad 'callback' function")

	local maid = Maid.new()

	local handleClassChanged = BoundLinkConnectionUtils._makeChangedHandlerWith(maid, callback)
	maid:GiveTask(binder:ObserveInstance(instance, handleClassChanged))
	handleClassChanged(binder:Get(instance))

	return maid
end

function BoundLinkConnectionUtils.connectToBoundClasses(bindersList, instance, callback)
	assert(bindersList, "Bad 'bindersList' list")
	assert(typeof(instance) == "Instance", "Bad 'instance' instance")
	assert(typeof(callback) == "function", "Bad 'callback' function")

	local maid = Maid.new()

	for _, binder in pairs(bindersList) do
		maid:GiveTask(BoundLinkConnectionUtils.connectToBoundClass(binder, instance, callback))
	end

	return maid
end

function BoundLinkConnectionUtils._makeChangedHandlerWith(topMaid, callback)
	assert(topMaid, "Bad 'topMaid' maid")
	assert(type(callback) == "function", "Bad 'callback' function")

	return function(value, ...)
		if value ~= nil then
			local maid = Maid.new()
			topMaid._callbackMaid = maid
			callback(maid, value, ...)
		else
			topMaid._callbackMaid = nil
			-- TODO: Call callback
		end
	end
end

function BoundLinkConnectionUtils._makeChangedHandlerWithNoCheck(topMaid, callback)
	assert(topMaid, "Bad 'topMaid' maid")
	assert(type(callback) == "function", "Bad 'callback' function")

	return function(value, ...)
		local maid = Maid.new()
		topMaid._callbackMaid = maid
		callback(maid, value, ...)
	end
end


return BoundLinkConnectionUtils