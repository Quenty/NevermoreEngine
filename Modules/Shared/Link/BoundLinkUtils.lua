---
-- @module BoundLinkUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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

	local classes = BoundLinkUtils.getClassesForLinkValues(binders, linkName, from)
	local called = {}

	for _, class in pairs(classes) do
		if class[methodName] then
			if not called[class] then
				class[methodName](class, unpack(args))
				called[class] = true
			else
				warn("[BoundLinkUtils.callMethodOnLinkedClasses] - Double-linked class")
			end
		end
	end
end

return BoundLinkUtils