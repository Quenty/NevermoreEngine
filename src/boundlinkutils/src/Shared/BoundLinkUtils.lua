--[=[
	Utility functions involving binders and links. It's a common pattern to link
	back to a bound class. This allows you to quickly retrieve these objects.

	@class BoundLinkUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local LinkUtils = require("LinkUtils")
local BinderUtils = require("BinderUtils")

local BoundLinkUtils = {}

--[=[
	Gets a linked object from the current instance.

	@param binder Binder<T>
	@param linkName string
	@param from Instance
	@return T?
]=]
function BoundLinkUtils.getLinkClass(binder, linkName, from)
	assert(type(binder) == "table", "Bad binder")
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad froM")

	local linkValue = LinkUtils.getLinkValue(linkName, from)
	if not linkValue then
		return nil
	end

	return binder:Get(linkValue)
end

--[=[
	Gets a linked objects from the current instance.

	@param binder Binder<T>
	@param linkName string
	@param from Instance
	@return { T }
]=]
function BoundLinkUtils.getLinkClasses(binder, linkName, from)
	assert(type(binder) == "table", "Bad binder")
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	local classes = {}
	for _, value in LinkUtils.getAllLinkValues(linkName, from) do
		local class = binder:Get(value)
		if class then
			table.insert(classes, class)
		end
	end
	return classes
end

--[=[
	Gets a linked objects from the current instance.

	@param binders { Binder<T> }
	@param linkName string
	@param from Instance
	@return { T }
]=]
function BoundLinkUtils.getClassesForLinkValues(binders, linkName, from)
	assert(type(binders) == "table", "Bad binders")
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad from")

	if not next(binders) then
		return {}
	end

	local tags = BinderUtils.mapBinderListToTable(binders)
	local classes = {}

	for _, instance in LinkUtils.getAllLinkValues(linkName, from) do
		for _, tag in CollectionService:GetTags(instance) do
			local binder = tags[tag]
			if binder then
				local obj = binder:Get(instance)
				if obj then
					table.insert(classes, obj)
				end
			end
		end
	end

	return classes
end

--[=[
	Calls a method on the binders

	@param binders { Binder<T> }
	@param linkName string
	@param from Instance
	@param methodName string
	@param args {}
]=]
function BoundLinkUtils.callMethodOnLinkedClasses(binders, linkName, from, methodName, args)
	assert(type(binders) == "table", "Bad arg 'binders'")
	assert(type(linkName) == "string", "Bad arg 'linkName'")
	assert(typeof(from) == "Instance", "Bad arg 'from'")
	assert(type(methodName) == "string", "Bad arg 'methodName'")
	assert(type(args) == "table", "Bad arg 'args'")

	if not next(binders) then
		return
	end

	local tags = BinderUtils.mapBinderListToTable(binders)

	local called = {}

	local function callForTag(value, tag)
		local binder = tags[tag]
		if not binder then
			return
		end

		local class = binder:Get(value)
		if not class then
			return
		end

		if not class[methodName] then
			return
		end

		if called[class] then
			warn(
				string.format(
					"[BoundLinkUtils.callMethodOnLinkedClasses] - Double-linked class %q for method %q",
					tag,
					methodName
				)
			)
			return
		end

		called[class] = true
		class[methodName](class, unpack(args))
	end

	for _, value in LinkUtils.getAllLinkValues(linkName, from) do
		for _, tag in CollectionService:GetTags(value) do
			callForTag(value, tag)
		end
	end
end

return BoundLinkUtils