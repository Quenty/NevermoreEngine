--- Utility functions for links. Links are object values pointing to other values!
-- @module LinkUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local promisePropertyValue = require("promisePropertyValue")
local promiseChild = require("promiseChild")

local LinkUtils = {}

function LinkUtils.createLink(name, from, to)
	assert(type(name) == "string")
	assert(typeof(from) == "Instance")
	assert(typeof(to) == "Instance")

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = name
	objectValue.Value = to
	objectValue.Parent = from

	return objectValue
end

function LinkUtils.getAllLinkValues(name, from)
	assert(type(name) == "string")
	assert(typeof(from) == "Instance")

	local linkValues = {}
	for _, item in pairs(from:GetChildren()) do
		if item.Name == name and item.Value then
			table.insert(linkValues, item.Value)
		end
	end

	return linkValues
end


function LinkUtils.getAllLinks(name, from)
	assert(type(name) == "string")
	assert(typeof(from) == "Instance")

	local links = {}
	for _, item in pairs(from:GetChildren()) do
		if item.Name == name then
			table.insert(links, item)
		end
	end

	return links
end

function LinkUtils.getLinkValue(name, from)
	assert(type(name) == "string")
	assert(typeof(from) == "Instance")

	local objectValue = from:FindFirstChild(name)
	if not objectValue then
		return nil
	end

	return objectValue.Value
end

function LinkUtils.promiseLinkValue(maid, linkName, from)
	assert(maid)
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

	return promiseChild(from, linkName)
		:Then(function(objectValue)
			local promise = promisePropertyValue(objectValue, "Value")
			maid:GiveTask(promise)

			return promise
		end)
end

return LinkUtils