--[=[
	Entry point for the Roblox API dump, this class contains api surfaces to
	query the actual API.
	@class RobloxApiDump
]=]

local require = require(script.Parent.loader).load(script)

local RobloxApiUtils = require("RobloxApiUtils")
local Promise = require("Promise")
local RobloxApiMember = require("RobloxApiMember")
local RobloxApiClass = require("RobloxApiClass")
local BaseObject = require("BaseObject")
local RobloxApiDumpConstants = require("RobloxApiDumpConstants")

local RobloxApiDump = setmetatable({}, BaseObject)
RobloxApiDump.ClassName = "RobloxApiDump"
RobloxApiDump.__index = RobloxApiDump

export type RobloxApiDump = typeof(setmetatable(
	{} :: {
		_classMemberPromises: { [string]: Promise.Promise<()> },
		_ancestorListPromise: { [string]: Promise.Promise<()> },
		_classPromises: { [string]: Promise.Promise<()> },
		_classMapPromise: Promise.Promise<()>?,
		_dumpPromise: Promise.Promise<()>?,
		_className: string,
		_obj: Instance?,
		_maid: any,
	},
	{} :: typeof({ __index = RobloxApiDump })
)) & BaseObject.BaseObject

--[=[
	Constructs a new RobloxApiDump which will cache all results for its lifetime.
	@return RobloxApiDump
]=]
function RobloxApiDump.new(): RobloxApiDump
	local self: RobloxApiDump = setmetatable(BaseObject.new() :: any, RobloxApiDump)

	self._classMemberPromises = {}
	self._ancestorListPromise = {}
	self._classPromises = {}

	return self
end

--[=[
	Promises the Roblox API class for the given class name.
	@param className string
	@return RobloxApiClass
]=]
function RobloxApiDump:PromiseClass(className: string)
	assert(type(className) == "string", "Bad className")

	if self._classPromises[className] then
		return self._classPromises[className]
	end

	self._classPromises[className] = self:_promiseRawClassData(className):Then(function(classData)
		return RobloxApiClass.new(self, classData)
	end)

	return self._classPromises[className]
end

--[=[
	Promises all Roblox API members.
	@param className string
	@return { RobloxApiMember }
]=]
function RobloxApiDump:PromiseMembers(className: string)
	assert(type(className) == "string", "Bad className")

	if self._classMemberPromises[className] then
		return self._classMemberPromises[className]
	end

	self._classMemberPromises[className] = self:_promiseClassDataAndAncestorList(className):Then(function(list)
		local members = {}
		for _, entry in list do
			if entry.Members then
				for _, member in entry.Members do
					table.insert(members, RobloxApiMember.new(member))
				end
			end
		end

		return members
	end)

	return self._classMemberPromises[className]
end

function RobloxApiDump:_promiseClassDataAndAncestorList(className: string)
	assert(type(className) == "string", "Bad className")

	if self._ancestorListPromise[className] then
		return self._ancestorListPromise[className]
	end

	self._ancestorListPromise[className] = self:_promiseClassMap():Then(function(classMap)
		local current = classMap[className]
		if not current then
			return Promise.rejected(string.format("Could not find data for %q", className))
		end

		local dataList = {}
		while current do
			table.insert(dataList, current)

			local superclass = current.Superclass
			if superclass and superclass ~= RobloxApiDumpConstants.ROOT_CLASS_NAME then
				current = classMap[superclass]
				if not current then
					return Promise.rejected(string.format("Could not find data for super class %q", superclass))
				end
			else
				current = nil
			end
		end

		return dataList
	end)

	return self._ancestorListPromise[className]
end

function RobloxApiDump:_promiseRawClassData(className: string)
	assert(type(className) == "string", "Bad className")

	return self:_promiseClassMap():Then(function(classMap)
		local data = classMap[className]
		if data then
			return data
		else
			return Promise.rejected(string.format("Could not find data for %q", className))
		end
	end)
end

function RobloxApiDump:_promiseClassMap()
	if self._classMapPromise then
		return self._classMapPromise
	end

	self._classMapPromise = self:_promiseDump():Then(function(dump)
		assert(dump.Version == 1, "Only able to parse version 1 of the dump")

		local classMap = {}
		for _, entry in dump.Classes do
			assert(type(entry) == "table", "Bad entry")
			assert(type(entry.Name) == "string", "Bad entry.Name")

			if classMap[entry.Name] then
				warn(string.format("[RobloxApiDump] - Duplicate entry for %q", tostring(entry.Name)))
				return
			end

			classMap[entry.Name] = entry
		end

		return classMap
	end)

	return self._classMapPromise
end

function RobloxApiDump:_promiseDump()
	if self._dumpPromise then
		return self._dumpPromise
	end

	self._dumpPromise = RobloxApiUtils.promiseDump()
	return self._maid:GivePromise(self._dumpPromise)
end

return RobloxApiDump