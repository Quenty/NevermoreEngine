--!strict
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

export type BinderGroupProvider = typeof(setmetatable(
	{} :: {
		_initMethod: (BinderGroupProvider, ...any) -> (),
		_groupsAddedPromise: Promise.Promise<()>,
		_init: boolean,
		_binderGroups: { any },
	},
	{} :: typeof({ __index = BinderGroupProvider })
))

--[=[
	Constructs a new BinderGroupProvider
	@param initMethod (BinderGroupProvider) -> ()
	@return BinderGroupProvider
]=]
function BinderGroupProvider.new(initMethod: (BinderGroupProvider, ...any) -> ()): BinderGroupProvider
	local self: BinderGroupProvider = setmetatable({} :: any, BinderGroupProvider)

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
function BinderGroupProvider.PromiseGroupsAdded(self: BinderGroupProvider): Promise.Promise<()>
	return self._groupsAddedPromise
end

--[=[
	Starts the binder provider. Should be called via ServiceBag.
	@param ... ServiceBag | any
]=]
function BinderGroupProvider.Init(self: BinderGroupProvider, ...: any): ()
	assert(not self._init, "Already initialized")

	self._initMethod(self, ...)
	self._init = true

	self._groupsAddedPromise:Resolve()
end

--[=[
	Starts the binder provider. Should be called via ServiceBag.
]=]
function BinderGroupProvider.Start(self: BinderGroupProvider): ()
	-- Do nothing
end

(BinderGroupProvider :: any).__index = function(self, index)
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
function BinderGroupProvider.Get(self: BinderGroupProvider, groupName: string): any
	assert(type(groupName) == "string", "Bad groupName")
	return rawget(self :: any, groupName)
end

--[=[
	Adds a new group at the given name

	@param groupName string
	@param binderGroup BinderGroup
]=]
function BinderGroupProvider.Add(self: BinderGroupProvider, groupName: string, binderGroup: any): ()
	assert(type(groupName) == "string", "Bad groupName")
	assert(type(binderGroup) == "table", "Bad binderGroup")
	assert(not self._init, "Already initialized")
	assert(not self:Get(groupName), "Duplicate groupName")

	table.insert(self._binderGroups, binderGroup);
	(self :: any)[groupName] = binderGroup
end

function BinderGroupProvider.Destroy(self: BinderGroupProvider): ()
	-- Do nothing
end

return BinderGroupProvider
