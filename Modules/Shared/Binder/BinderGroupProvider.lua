--- Provides a basis for binderGroups that can be retrieved anywhere
-- @classmod BinderGroupProvider

local BinderGroupProvider = {}
BinderGroupProvider.ClassName = "BinderGroupProvider"
BinderGroupProvider.__index = BinderGroupProvider

function BinderGroupProvider.new(initMethod)
	local self = setmetatable({}, BinderGroupProvider)

	self._initMethod = initMethod or error("No initMethod")

	self._afterInit = false
	self._binderGroups = {}

	return self
end

function BinderGroupProvider:Init()
	self:_initMethod(self)
	self._afterInit = true
end

function BinderGroupProvider:__index(index)
	if BinderGroupProvider[index] then
		return BinderGroupProvider[index]
	end

	error(("%q Not a valid index"):format(tostring(index)))
end

function BinderGroupProvider:Get(tagName)
	assert(type(tagName) == "string", "tagName must be a string")
	return rawget(self, tagName)
end

function BinderGroupProvider:Add(groupName, binderGroup)
	assert(type(groupName) == "string")
	assert(type(binderGroup) == "table")
	assert(not self._afterInit, "Already inited")
	assert(not self:Get(groupName), "Duplicate groupName")

	table.insert(self._binderGroups, binderGroup)
	self[groupName] = binderGroup
end

return BinderGroupProvider