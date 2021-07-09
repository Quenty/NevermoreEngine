--- Utility functions for links. Links are object values pointing to other values!
-- @module LinkUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local promisePropertyValue = require("promisePropertyValue")
local promiseChild = require("promiseChild")

local LinkUtils = {}

function LinkUtils.createLink(linkName, from, to)
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")
	assert(typeof(to) == "Instance")

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = linkName
	objectValue.Value = to
	objectValue.Parent = from

	return objectValue
end

function LinkUtils.getAllLinkValues(linkName, from)
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

	local linkValues = {}

	for _, item in pairs(from:GetChildren()) do
		if item:IsA("ObjectValue") and item.Name == linkName then
			local value = item.Value
			if value then
				table.insert(linkValues, value)
			end
		end
	end

	return linkValues
end


function LinkUtils.getAllLinks(linkName, from)
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

	local links = {}
	for _, item in pairs(from:GetChildren()) do
		if item:IsA("ObjectValue") and item.Name == linkName then
			table.insert(links, item)
		end
	end

	return links
end

function LinkUtils.getLinkValue(linkName, from)
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

	local objectValue = from:FindFirstChild(linkName)
	if not objectValue then
		return nil
	end

	if not objectValue:IsA("ObjectValue") then
		warn(("[LinkUtils.getLinkValue] - Bad link %q not an object value, from %q")
			:format(objectValue:GetFullName(), from:GetFullName()))
		return nil
	end

	return objectValue.Value
end

function LinkUtils.promiseLinkValue(maid, linkName, from)
	assert(maid)
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

	local childPromise = promiseChild(from, linkName)
	maid:GiveTask(childPromise)

	return childPromise:Then(function(objectValue)
		local promise = promisePropertyValue(objectValue, "Value")
		maid:GiveTask(promise)

		return promise
	end)
end

return LinkUtils