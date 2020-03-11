---
-- @module BoundLinkUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")

local LinkUtils = require("LinkUtils")

local BoundLinkUtils = {}

function BoundLinkUtils.getBoundLinkValues(binder, linkName, from)
	assert(type(binder) == "table")
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")

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

	local classes = {}
	for _, value in pairs(LinkUtils.getAllLinkValues(linkName, from)) do
		for _, binder in pairs(binders) do
			local class = binder:Get(value)
			if class then
				table.insert(classes, class)
			end
		end
	end
	return classes
end

function BoundLinkUtils.callMethodOnLinkedClasses(binders, linkName, from, methodName, args)
	assert(type(binders) == "table")
	assert(type(linkName) == "string")
	assert(typeof(from) == "Instance")
	assert(type(methodName) == "string")
	assert(type(args) == "table")

	local tagged = {}
	for _, item in pairs(binders) do
		tagged[item:GetTag()] = item
	end

	local called = {}

	local function callForTag(value, tag)
		local binder = tagged[tag]
		if not binder then
			return
		end

		local class = binder:Get(value)
		if not class then
			return
		end

		if not class[methodName] then
			warn(("BoundLinkUtils.callMethodOnLinkedClasses] - Class doesn't have method %q"):format(methodName))
			return
		end

		if called[class] then
			warn("[BoundLinkUtils.callMethodOnLinkedClasses] - Double-linked class")
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