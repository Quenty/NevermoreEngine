--[=[
	Captures a snapshot of data to write and then merges it with the original.
	@server
	@class DataStoreWriter
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")
local DataStoreDeleteToken = require("DataStoreDeleteToken")
local Symbol = require("Symbol")
local Set = require("Set")

local UNSET_TOKEN = Symbol.named("unsetValue")

local DataStoreWriter = {}
DataStoreWriter.ClassName = "DataStoreWriter"
DataStoreWriter.__index = DataStoreWriter

--[=[
	Constructs a new DataStoreWriter. In general, you will not use this API directly.

	@param debugName string
	@return DataStoreWriter
]=]
function DataStoreWriter.new(debugName)
	local self = setmetatable({}, DataStoreWriter)

	self._debugName = assert(debugName, "No debugName")
	self._saveDataSnapshot = UNSET_TOKEN
	self._fullBaseDataSnapshot = UNSET_TOKEN
	self._diffData = UNSET_TOKEN
	self._userIdList = UNSET_TOKEN

	self._writers = {}

	return self
end

--[=[
	Sets the ray data to write
	@param saveDataSnapshot table | any
]=]
function DataStoreWriter:SetSaveDataSnapshot(saveDataSnapshot)
	assert(type(saveDataSnapshot) ~= "table" or table.isfrozen(saveDataSnapshot), "saveDataSnapshot should be frozen")

	if saveDataSnapshot == DataStoreDeleteToken then
		self._saveDataSnapshot = DataStoreDeleteToken
	elseif type(saveDataSnapshot) == "table" then
		self._saveDataSnapshot = Table.deepCopy(saveDataSnapshot)
	else
		self._saveDataSnapshot = saveDataSnapshot
	end
end

function DataStoreWriter:GetDataToSave()
	if self._saveDataSnapshot == UNSET_TOKEN then
		return nil
	end

	return self._saveDataSnapshot
end

function DataStoreWriter:GetSubWritersMap()
	return self._writers
end

function DataStoreWriter:SetFullBaseDataSnapshot(fullBaseDataSnapshot)
	assert(type(fullBaseDataSnapshot) ~= "table" or table.isfrozen(fullBaseDataSnapshot), "fullBaseDataSnapshot should be frozen")

	if fullBaseDataSnapshot == DataStoreDeleteToken then
		error("[DataStoreWriter] - fullBaseDataSnapshot should not be a delete token")
	end

	self._fullBaseDataSnapshot = fullBaseDataSnapshot
end

--[=[
	Adds a recursive child writer to use at the key `name`
	@param name string
	@param writer DataStoreWriter
]=]
function DataStoreWriter:AddSubWriter(name, writer)
	assert(type(name) == "string", "Bad name")
	assert(not self._writers[name], "Writer already exists for name")
	assert(writer, "Bad writer")

	self._writers[name] = writer
end

--[=[
	Gets a sub writer

	@param name string
	@return DataStoreWriter
]=]
function DataStoreWriter:GetWriter(name)
	assert(type(name) == "string", "Bad name")

	return self._writers[name]
end

--[=[
	Merges the incoming data.

	Won't really perform a delete operation because we can't be sure if we were suppose to have reified this stuff or not.
]=]
function DataStoreWriter:StoreDifference(incoming)
	assert(incoming ~= DataStoreDeleteToken, "Incoming value should not be DataStoreDeleteToken")

	if type(incoming) == "table" then
		self._diffData = {}

		for key, value in pairs(incoming) do
			-- Route to writers first
			if self._writers[key] then
				self._writers[key]:StoreDifference(value)
			elseif type(self._fullBaseDataSnapshot) == "table" then
				self._diffData[key] = self:_computeValueDiff(self._fullBaseDataSnapshot[key], value)
			else
				self._diffData[key] = self:_computeValueDiff(nil, value)
			end
		end
	else
		self._diffData = self:_computeValueDiff(self._fullBaseDataSnapshot, incoming)
	end
end

function DataStoreWriter:_computeValueDiff(original, incoming)
	if original == incoming then
		return nil
	end

	if incoming == DataStoreDeleteToken and original == nil then
		return nil
	end

	if type(original) == "table" and type(incoming) == "table" then
		return self:_computeTableDiff(original, incoming)
	end

	return incoming
end

function DataStoreWriter:_computeTableDiff(original, incoming)
	assert(type(original) == "table", "Bad original")
	assert(type(incoming) == "table", "Bad incoming")

	local keys = Set.union(Set.fromKeys(original), Set.fromKeys(incoming))

	local diff = {}
	for key, _ in pairs(keys) do
		diff[key] = self:_computeValueDiff(original[key], incoming[key])
	end

	if next(diff) ~= nil then
		return diff
	else
		return nil
	end
end

function DataStoreWriter:GetDiffData()
	-- Prioritize our value first, followed by writers
	if self._diffData == DataStoreDeleteToken then
		return DataStoreDeleteToken
	elseif self._diffData == UNSET_TOKEN or self._diffData == nil or type(self._diffData) == "table" then
		return self:_mergeDiffDataWithWriters()
	else
		return self._diffData
	end
end

function DataStoreWriter:_mergeDiffDataWithWriters()
	local result = {}

	-- Writers are overwritten by diff data
	for key, writer in pairs(self._writers) do
		result[key] = writer:GetDiffData()
	end

	if type(self._diffData) == "table" then
		for key, value in pairs(self._diffData) do
			if result[key] ~= nil then
				warn(string.format("[DataStoreWriter._mergeDiffDataWithWriters] - Overwriting diff data %q already from a writer", key))
			end

			result[key] = value
		end
	end

	if next(result) ~= nil then
		return result
	end

	return nil
end

function DataStoreWriter:SetUserIdList(userIdList)
	assert(type(userIdList) == "table" or userIdList == nil, "Bad userIdList")

	self._userIdList = userIdList
end

function DataStoreWriter:GetUserIdList()
	if self._userIdList == UNSET_TOKEN then
		return nil
	end

	return self._userIdList
end

function DataStoreWriter:_writeMergeWriters(original)
	local copy
	if type(original) == "table" then
		copy = table.clone(original)
	else
		copy = original
	end

	if next(self._writers) ~= nil then
		-- Original was not a table. We need to swap to one.
		if type(copy) ~= "table" then
			copy = {}
		end

		-- Write our writers first...
		for key, writer in pairs(self._writers) do
			local result = writer:WriteMerge(copy[key])
			if result == DataStoreDeleteToken then
				copy[key] = nil
			else
				copy[key] = result
			end
		end
	end

	-- Write our save data next
	if type(self._saveDataSnapshot) == "table" and next(self._saveDataSnapshot) ~= nil then
		-- Original was not a table. We need to swap to one.
		if type(copy) ~= "table" then
			copy = {}
		end

		for key, value in pairs(self._saveDataSnapshot) do
			if self._writers[key] then
				warn(string.format("[DataStoreWriter._writeMergeWriters] - Overwriting key %q already saved as rawData with a writer with %q (was %q)", key, tostring(value), tostring(copy[key])))
			end

			if value == DataStoreDeleteToken then
				copy[key] = nil
			else
				copy[key] = value
			end
		end
	end

	return copy
end

--[=[
	Merges the new data into the original value

	@param original any
	@return any -- The original value
]=]
function DataStoreWriter:WriteMerge(original)
	-- Prioritize save value first, followed by writers, followed by original value

	if self._saveDataSnapshot == DataStoreDeleteToken then
		return DataStoreDeleteToken
	elseif self._saveDataSnapshot == UNSET_TOKEN or self._saveDataSnapshot == nil or type(self._saveDataSnapshot) == "table" then
		return self:_writeMergeWriters(original)
	else
		-- Save data must be a boolean or something
		return self._saveDataSnapshot
	end
end

function DataStoreWriter:IsCompleteWipe()
	if self._saveDataSnapshot == UNSET_TOKEN then
		return false
	end

	if self._saveDataSnapshot == DataStoreDeleteToken then
		return true
	end

	return false
end

return DataStoreWriter