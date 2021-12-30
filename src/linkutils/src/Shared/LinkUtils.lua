--[=[
	Utility functions for links. Links are an [ObjectValue] pointing to something else!
	@class LinkUtils
]=]

local require = require(script.Parent.loader).load(script)

local promisePropertyValue = require("promisePropertyValue")
local promiseChild = require("promiseChild")

local LinkUtils = {}

--[=[
	Creates a new link with the given name.
	@param linkName string
	@param from Instance
	@param to Instance
	@return ObjectValue
]=]
function LinkUtils.createLink(linkName, from, to)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")
	assert(typeof(to) == "Instance", "Bad to")

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = linkName
	objectValue.Value = to
	objectValue.Parent = from

	return objectValue
end

--[=[
	Gets all link values, as long as the values are not nil.
	@param linkName string
	@param from Instance
	@return { Instance }
]=]
function LinkUtils.getAllLinkValues(linkName, from)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

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

--[=[
	Gets all links underneath an instance.
	@param linkName string
	@param from Instance
	@return { ObjectValue }
]=]
function LinkUtils.getAllLinks(linkName, from)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local links = {}
	for _, item in pairs(from:GetChildren()) do
		if item:IsA("ObjectValue") and item.Name == linkName then
			table.insert(links, item)
		end
	end

	return links
end

--[=[
	Gets the first links value
	@param linkName string
	@param from Instance
	@return { Instance }
]=]
function LinkUtils.getLinkValue(linkName, from)
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

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

--[=[
	Promises the first link value that is truthy
	@param maid Maid
	@param linkName string
	@param from Instance
	@return Promise<Instance>
]=]
function LinkUtils.promiseLinkValue(maid, linkName, from)
	assert(maid, "Bad maid")
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local childPromise = promiseChild(from, linkName)
	maid:GiveTask(childPromise)

	return childPromise:Then(function(objectValue)
		local promise = promisePropertyValue(objectValue, "Value")
		maid:GiveTask(promise)

		return promise
	end)
end

return LinkUtils