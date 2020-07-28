---
-- @module BoundLinkUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")

local LinkUtils = require("LinkUtils")
local BinderUtils = require("BinderUtils")

local BoundLinkUtils = {}

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

function BoundLinkUtils.getLinkClasses(binder, linkName, from)
	assert(type(binder) == "table", "Bad binder")
	assert(type(linkName) == "string", "Bad linkName")
	assert(typeof(from) == "Instance", "Bad froM")

	local classes = {}
	for _, value in pairs(LinkUtils.getAllLinkValues(linkName, from)) do
		local class = binder:Get(value)
		if class then
			table.insert(classes, class)
		end
	end
	return classes
end

function BoundLinkUtils.getClassesForLinkValues(binders, linkName, from)
	assert(type(binders) == "table")
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

	if not next(binders) then
		return {}
	end

	local tags = BinderUtils.mapBinderListToTable(binders)
	local classes = {}

	for _, instance in pairs(LinkUtils.getAllLinkValues(linkName, from)) do
		for _, tag in pairs(CollectionService:GetTags(instance)) do
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
			warn(("[BoundLinkUtils.callMethodOnLinkedClasses] - Double-linked class %q for method %q"):format(tag, methodName))
			return
		end

		called[class] = true
		class[methodName](class, unpack(args))
	end

	for _, value in pairs(LinkUtils.getAllLinkValues(linkName, from)) do
		for _, tag in pairs(CollectionService:GetTags(value)) do
			callForTag(value, tag)
		end
	end
end

return BoundLinkUtils