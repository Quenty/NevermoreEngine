--!strict
--[=[
	Utility functions for links. Links are an [ObjectValue] pointing to something else!
	@class LinkUtils
]=]

local require = require(script.Parent.loader).load(script)

local promiseChild = require("promiseChild")
local promisePropertyValue = require("promisePropertyValue")

local LinkUtils = {}

--[=[
	Creates a new link with the given name.
	@param linkName string
	@param from Instance
	@param to Instance
	@return ObjectValue
]=]
function LinkUtils.createLink(linkName: string, from: Instance, to: Instance): ObjectValue
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")
	assert(typeof(to) == "Instance", "Bad to")

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = linkName
	objectValue.Value = to
	objectValue.Archivable = false
	objectValue.Parent = from

	return objectValue
end

--[=[
	Gets all link values, as long as the values are not nil.
	@param linkName string
	@param from Instance
	@return { Instance }
]=]
function LinkUtils.getAllLinkValues(linkName: string, from: Instance): { Instance }
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local linkValues: { Instance } = {}

	for _, item in from:GetChildren() do
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
	Ensures after operation a single link is pointed to the value, unless the value is "nil"
	in which case no link will be set

	@param linkName string
	@param from Instance
	@param to Instance
	@return Instance?
]=]
function LinkUtils.setSingleLinkValue(linkName: string, from: Instance, to: Instance): ObjectValue?
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")
	assert(typeof(to) == "Instance" or to == nil, "Bad to")

	if to then
		local existingLink = nil
		for _, link in from:GetChildren() do
			if link:IsA("ObjectValue") and link.Name == linkName then
				if existingLink then
					link:Destroy()
				else
					existingLink = link
					link.Value = to
				end
			end
		end

		if existingLink then
			return existingLink
		end

		return LinkUtils.createLink(linkName, from, to)
	else
		for _, link in from:GetChildren() do
			if link:IsA("ObjectValue") and link.Name == linkName then
				link:Destroy()
			end
		end

		return nil
	end
end

--[=[
	Gets all links underneath an instance.
	@param linkName string
	@param from Instance
	@return { ObjectValue }
]=]
function LinkUtils.getAllLinks(linkName: string, from: Instance): { ObjectValue }
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local links = {}
	for _, item in from:GetChildren() do
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
	@return Instance
]=]
function LinkUtils.getLinkValue(linkName: string, from: Instance): Instance?
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local objectValue = from:FindFirstChild(linkName)
	if not objectValue then
		return nil
	end

	if not objectValue:IsA("ObjectValue") then
		warn(
			string.format(
				"[LinkUtils.getLinkValue] - Bad link %q not an object value, from %q",
				objectValue:GetFullName(),
				from:GetFullName()
			)
		)
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
function LinkUtils.promiseLinkValue(maid, linkName: string, from: Instance)
	assert(maid, "Bad maid")
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local childPromise = promiseChild(from, linkName)
	maid:GiveTask(childPromise)

	return childPromise:Then(function(objectValue: ObjectValue)
		local promise = promisePropertyValue(objectValue, "Value")
		maid:GiveTask(promise)

		return promise
	end)
end

return LinkUtils
