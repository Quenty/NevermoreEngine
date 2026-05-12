--!strict
--[=[
	Entry point for the Roblox API dump, this class contains api surfaces to
	query the actual API.
	@class RobloxApiDump
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local RobloxApiClass = require("RobloxApiClass")
local RobloxApiDataTypes = require("RobloxApiDataTypes")
local RobloxApiDumpConstants = require("RobloxApiDumpConstants")
local RobloxApiMember = require("RobloxApiMember")

local RobloxApiDump = setmetatable({}, BaseObject)
RobloxApiDump.ClassName = "RobloxApiDump"
RobloxApiDump.__index = RobloxApiDump

export type PromiseDumpCallback = () -> Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>

export type RobloxApiDump =
	typeof(setmetatable(
		{} :: {
			_classMemberPromises: { [string]: Promise.Promise<{ RobloxApiMember.RobloxApiMember }> },
			_ancestorListPromise: { [string]: Promise.Promise<{ RobloxApiDataTypes.ClassData }> },
			_classPromises: { [string]: Promise.Promise<RobloxApiClass.RobloxApiClass> },
			_classMapPromise: Promise.Promise<RobloxApiDataTypes.ClassMap>?,
			_dumpPromiseCallback: PromiseDumpCallback,
			_dumpPromiseCache: Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>?,
			_className: string,
		},
		{} :: typeof({ __index = RobloxApiDump })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new RobloxApiDump which will cache all results for its lifetime.
	@return RobloxApiDump
]=]
function RobloxApiDump.new(promiseDumpCallback: PromiseDumpCallback): RobloxApiDump
	assert(promiseDumpCallback, "Must provide promiseDumpCallback")

	local self: RobloxApiDump = setmetatable(BaseObject.new() :: any, RobloxApiDump)

	self._classMemberPromises = {}
	self._ancestorListPromise = {}
	self._classPromises = {}
	self._dumpPromiseCallback = promiseDumpCallback

	return self
end

--[=[
	Promises the Roblox API class for the given class name.
	@param className string
	@return RobloxApiClass
]=]
function RobloxApiDump.PromiseClass(
	self: RobloxApiDump,
	className: string
): Promise.Promise<RobloxApiClass.RobloxApiClass>
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
function RobloxApiDump.PromiseMembers(
	self: RobloxApiDump,
	className: string
): Promise.Promise<{ RobloxApiMember.RobloxApiMember }>
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

function RobloxApiDump._promiseClassDataAndAncestorList(
	self: RobloxApiDump,
	className: string
): Promise.Promise<{ RobloxApiDataTypes.ClassData }>
	assert(type(className) == "string", "Bad className")

	if self._ancestorListPromise[className] then
		return self._ancestorListPromise[className]
	end

	self._ancestorListPromise[className] = self:_promiseClassMap():Then(function(classMap)
		local current: any = classMap[className]
		if not current then
			return Promise.rejected(string.format("Could not find data for %q", className))
		end

		local dataList: any = {}
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

function RobloxApiDump._promiseRawClassData(
	self: RobloxApiDump,
	className: string
): Promise.Promise<RobloxApiDataTypes.ClassData>
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

function RobloxApiDump._promiseClassMap(self: RobloxApiDump): Promise.Promise<RobloxApiDataTypes.ClassMap>
	if self._classMapPromise then
		return self._classMapPromise
	end

	self._classMapPromise = self:PromiseRawDump():Then(function(dump)
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
	assert(self._classMapPromise, "Typechecking assetion")

	return self._classMapPromise
end

function RobloxApiDump.PromiseRawDump(self: RobloxApiDump): Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>
	if self._dumpPromiseCache then
		return self._dumpPromiseCache
	end

	self._dumpPromiseCache = self._maid:GivePromise(self._dumpPromiseCallback())
	assert(self._dumpPromiseCache, "Typechecking assertion")

	return self._dumpPromiseCache
end

return RobloxApiDump
