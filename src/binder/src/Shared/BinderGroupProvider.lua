--[=[
	Provides a basis for binderGroups that can be retrieved anywhere
	@class BinderGroupProvider
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local BinderGroupProvider = {}
BinderGroupProvider.ClassName = "BinderGroupProvider"
BinderGroupProvider.ServiceName = "BinderGroupProvider"
BinderGroupProvider.__index = BinderGroupProvider

--[=[
	Constructs a new BinderGroupProvider
	@param initMethod (BinderGroupProvider) -> ()
	@return BinderGroupProvider
]=]
function BinderGroupProvider.new(initMethod)
	local self = setmetatable({}, BinderGroupProvider)

	self._initMethod = initMethod or error("No initMethod")
	self._groupsAddedPromise = Promise.new()

	self._init = false
	self._binderGroups = {}

	return self
end

--[=[
	Returns a promise that will resolve once groups are added.
	@return Promise
]=]
function BinderGroupProvider:PromiseGroupsAdded()
	return self._groupsAddedPromise
end

--[=[
	Starts the binder provider. Should be called via ServiceBag.
	@param ... ServiceBag | any
]=]
function BinderGroupProvider:Init(...)
	assert(not self._init, "Already initialized")

	self._initMethod(self, ...)
	self._init = true

	self._groupsAddedPromise:Resolve()
end

--[=[
	Starts the binder provider. Should be called via ServiceBag.
]=]
function BinderGroupProvider:Start()
	-- Do nothing
end

function BinderGroupProvider:__index(index)
	if BinderGroupProvider[index] then
		return BinderGroupProvider[index]
	end

	error(string.format("%q Not a valid index", tostring(index)))
end

--[=[
	Returns a binder group given the binderName

	@param groupName string
	@return BinderGroup?
]=]
function BinderGroupProvider:Get(groupName: string)
	assert(type(groupName) == "string", "Bad groupName")
	return rawget(self, groupName)
end

--[=[
	Adds a new group at the given name

	@param groupName string
	@param binderGroup BinderGroup
]=]
function BinderGroupProvider:Add(groupName, binderGroup)
	assert(type(groupName) == "string", "Bad groupName")
	assert(type(binderGroup) == "table", "Bad binderGroup")
	assert(not self._init, "Already initialized")
	assert(not self:Get(groupName), "Duplicate groupName")

	table.insert(self._binderGroups, binderGroup)
	self[groupName] = binderGroup
end

function BinderGroupProvider:Destroy()
	-- Do nothing
end

return BinderGroupProvider
