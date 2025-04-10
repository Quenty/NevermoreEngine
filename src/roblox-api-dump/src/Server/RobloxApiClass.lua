--!strict
--[=[
	Represents a specific Roblox class.
	@class RobloxApiClass
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local RobloxApiDumpConstants = require("RobloxApiDumpConstants")

local RobloxApiClass = {}
RobloxApiClass.ClassName = "RobloxApiClass"
RobloxApiClass.__index = RobloxApiClass

export type RobloxApiClass = typeof(setmetatable(
	{} :: {
		_robloxApiDump: any,
		_data: any,
		_allSuperClassesPromise: Promise.Promise<any>?,
		_tagCache: { [string]: boolean }?,
	},
	{} :: typeof({ __index = RobloxApiClass })
))

--[=[
	Constructs a new RobloxApiClass. See [RobloxApiDump.PromiseClass] to actually construct
	this class.
	@param robloxApiDump RobloxApiDump
	@param data table
	@return RobloxApiClass
]=]
function RobloxApiClass.new(robloxApiDump, data): RobloxApiClass
	local self: RobloxApiClass = setmetatable({} :: any, RobloxApiClass)

	--[[
        {
            "Members": [
				...
            ],
            "MemoryCategory": "Instances",
            "Name": "PackageUIService",
            "Superclass": "Instance",
            "Tags": [
                "NotCreatable",
                "Service",
                "NotReplicated"
            ]
        },
	]]
	self._robloxApiDump = assert(robloxApiDump, "No robloxApiDump")
	self._data = assert(data, "No data")

	return self
end

--[=[
	Retrieves the raw class data
	@return table
]=]
function RobloxApiClass.GetRawData(self: RobloxApiClass): unknown
	return self._data
end

--[=[
	Gets the class name.
	@return string
]=]
function RobloxApiClass.GetClassName(self: RobloxApiClass): string
	assert(type(self._data.Name) == "string", "Bad Name")
	return self._data.Name
end

--[=[
	Gets the class category.
	@return string?
]=]
function RobloxApiClass.GetMemberCategory(self: RobloxApiClass): string?
	return self._data.MemoryCategory -- might be nil, stuff like "Data" or ""
end

--[=[
	Retrieves the super class, or rejects.
	@return Promise<RobloxApiClass>
]=]
function RobloxApiClass.PromiseSuperClass(self: RobloxApiClass): Promise.Promise<RobloxApiClass>
	local superclass = self:GetSuperClassName()
	if superclass then
		return self._robloxApiDump:PromiseClass(superclass)
	else
		return Promise.rejected("No super class")
	end
end

--[=[
	Returns a promise that resolves whether this class is of a specific type.
	@param className string
	@return Promise<boolean>
]=]
function RobloxApiClass.PromiseIsA(self: RobloxApiClass, className: string): Promise.Promise<boolean>
	if self:GetClassName() == className then
		return Promise.resolved(true)
	end

	return self:PromiseIsDescendantOf(className)
end

--[=[
	Returns a promise that resolves whether this class is a descendant of another
	specific class.

	@param className string
	@return Promise<boolean>
]=]
function RobloxApiClass.PromiseIsDescendantOf(self: RobloxApiClass, className: string)
	return self:PromiseAllSuperClasses():Then(function(classes)
		for _, class in classes do
			if class:GetClassName() == className then
				return true
			end
		end

		return false
	end)
end

--[=[
	Returns a promise that resolves to all super classes.
	@return Promise<{ RobloxApiClass }>
]=]
function RobloxApiClass.PromiseAllSuperClasses(self: RobloxApiClass): Promise.Promise<{ RobloxApiClass }>
	if self._allSuperClassesPromise then
		return self._allSuperClassesPromise
	end

	local list: { RobloxApiClass } = {}

	local function chain(current: RobloxApiClass): Promise.Promise<{ RobloxApiClass }>
		return current:PromiseSuperClass():Then(function(superclass)
			if superclass then
				table.insert(list, superclass)
				return chain(superclass)
			else
				return list :: any
			end
		end)
	end

	local promise = chain(self)
	self._allSuperClassesPromise = promise
	return promise
end

--[=[
	Returns the super class name
	@return string?
]=]
function RobloxApiClass.GetSuperClassName(self: RobloxApiClass)
	local data = self._data.Superclass
	if data == RobloxApiDumpConstants.ROOT_CLASS_NAME then
		return nil
	else
		return data
	end
end

--[=[
	Returns whether the class has a super class
	@return boolean
]=]
function RobloxApiClass.HasSuperClass(self: RobloxApiClass): boolean
	return self:GetSuperClassName() ~= nil
end

--[=[
	Retrieves all class members (events, properties, callbacks, functions).
	@return Promise<{ RobloxApiMember }>
]=]
function RobloxApiClass.PromiseMembers(self: RobloxApiClass)
	return self._robloxApiDump:PromiseMembers(self:GetClassName())
end

--[=[
	Gets all class properties.
	@return Promise<{ RobloxApiMember }>
]=]
function RobloxApiClass.PromiseProperties(self: RobloxApiClass)
	return self:PromiseMembers():Then(function(members)
		local result = {}
		for _, member in members do
			if member:IsProperty() then
				table.insert(result, member)
			end
		end
		return result
	end)
end

--[=[
	Gets all class events.
	@return Promise<{ RobloxApiMember }>
]=]
function RobloxApiClass.PromiseEvents(self: RobloxApiClass)
	return self:PromiseMembers():Then(function(members)
		local result = {}
		for _, member in members do
			if member:IsEvent() then
				table.insert(result, member)
			end
		end
		return result
	end)
end

--[=[
	Gets all class functions (i.e. methods).
	@return Promise<{ RobloxApiMember }>
]=]
function RobloxApiClass.PromiseFunctions(self: RobloxApiClass)
	return self:PromiseMembers():Then(function(members)
		local result = {}
		for _, member in members do
			if member:IsFunction() then
				table.insert(result, member)
			end
		end
		return result
	end)
end

--[=[
	Retrieves whether the class is a service
	@return boolean
]=]
function RobloxApiClass.IsService(self: RobloxApiClass): boolean
	return self:HasTag("Service")
end

--[=[
	Retrieves whether the class is not creatable
	@return boolean
]=]
function RobloxApiClass.IsNotCreatable(self: RobloxApiClass): boolean
	return self:HasTag("NotCreatable")
end

--[=[
	Retrieves whether the class is not replicated
	@return boolean
]=]
function RobloxApiClass.IsNotReplicated(self: RobloxApiClass): boolean
	return self:HasTag("NotReplicated")
end

--[=[
	Retrieves whether the class has a tag or not
	@param tagName string
	@return boolean
]=]
function RobloxApiClass.HasTag(self: RobloxApiClass, tagName: string): boolean
	if self._tagCache then
		return self._tagCache[tagName] == true
	end

	local cache = {}
	self._tagCache = cache

	if type(self._data.Tags) == "table" then
		for _, tag in self._data.Tags do
			cache[tag] = true
		end
	end

	return cache[tagName] == true
end

return RobloxApiClass