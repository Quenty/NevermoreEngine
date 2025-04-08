--!strict
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
local DataStoreSnapshotUtils = require("DataStoreSnapshotUtils")

local UNSET_TOKEN = Symbol.named("unsetValue")

local DataStoreWriter = {}
DataStoreWriter.ClassName = "DataStoreWriter"
DataStoreWriter.__index = DataStoreWriter

export type DataStoreStageKey = string | number

export type DataStoreWriter = typeof(setmetatable(
	{} :: {
		_debugName: string,
		_saveDataSnapshot: any,
		_fullBaseDataSnapshot: any,
		_userIdList: { number } | nil,
		_writers: { [DataStoreStageKey]: DataStoreWriter },
	},
	{} :: typeof({ __index = DataStoreWriter })
))

--[=[
	Constructs a new DataStoreWriter. In general, you will not use this API directly.

	@param debugName string
	@return DataStoreWriter
]=]
function DataStoreWriter.new(debugName: string): DataStoreWriter
	local self: DataStoreWriter = setmetatable({} :: any, DataStoreWriter)

	self._debugName = assert(debugName, "No debugName")
	self._saveDataSnapshot = UNSET_TOKEN
	self._fullBaseDataSnapshot = UNSET_TOKEN
	self._userIdList = UNSET_TOKEN

	self._writers = {}

	return self
end

--[=[
	Sets the ray data to write
	@param saveDataSnapshot table | any
]=]
function DataStoreWriter.SetSaveDataSnapshot(self: DataStoreWriter, saveDataSnapshot)
	assert(type(saveDataSnapshot) ~= "table" or table.isfrozen(saveDataSnapshot), "saveDataSnapshot should be frozen")

	if saveDataSnapshot == DataStoreDeleteToken then
		self._saveDataSnapshot = DataStoreDeleteToken
	elseif type(saveDataSnapshot) == "table" and not Symbol.isSymbol(saveDataSnapshot) then
		self._saveDataSnapshot = Table.deepCopy(saveDataSnapshot)
	else
		self._saveDataSnapshot = saveDataSnapshot
	end
end

function DataStoreWriter.GetDataToSave(self: DataStoreWriter): any
	if self._saveDataSnapshot == UNSET_TOKEN then
		return nil
	end

	return self._saveDataSnapshot
end

function DataStoreWriter.GetSubWritersMap(self: DataStoreWriter): { [DataStoreStageKey]: DataStoreWriter }
	return self._writers
end

function DataStoreWriter.SetFullBaseDataSnapshot(self: DataStoreWriter, fullBaseDataSnapshot)
	assert(
		type(fullBaseDataSnapshot) ~= "table" or table.isfrozen(fullBaseDataSnapshot),
		"fullBaseDataSnapshot should be frozen"
	)
	assert(not Symbol.isSymbol(fullBaseDataSnapshot), "fullBaseDataSnapshot should not be symbol")

	if fullBaseDataSnapshot == DataStoreDeleteToken then
		error("[DataStoreWriter] - fullBaseDataSnapshot should not be a delete token")
	end

	self._fullBaseDataSnapshot = fullBaseDataSnapshot
end

--[=[
	Adds a recursive child writer to use at the key `name`
	@param name string | number
	@param writer DataStoreWriter
]=]
function DataStoreWriter.AddSubWriter(self: DataStoreWriter, name: DataStoreStageKey, writer: DataStoreWriter)
	assert(type(name) == "string" or type(name) == "number", "Bad name")
	assert(not self._writers[name], "Writer already exists for name")
	assert(writer, "Bad writer")

	self._writers[name] = writer
end

--[=[
	Gets a sub writer

	@param name string | number
	@return DataStoreWriter
]=]
function DataStoreWriter.GetWriter(self: DataStoreWriter, name: DataStoreStageKey): DataStoreWriter?
	assert(type(name) == "string", "Bad name")

	return self._writers[name]
end

--[=[
	Merges the incoming data.

	Won't really perform a delete operation because we can't be sure if we were suppose to have reified this stuff or not.

	@param incoming any
]=]
function DataStoreWriter.ComputeDiffSnapshot(self: DataStoreWriter, incoming)
	assert(incoming ~= DataStoreDeleteToken, "Incoming value should not be DataStoreDeleteToken")
	assert(not Symbol.isSymbol(incoming), "Incoming should not be symbol")

	if type(incoming) == "table" then
		local keys = Set.union(Set.fromKeys(self._writers), Set.fromKeys(incoming))

		local baseSnapshot
		if type(self._fullBaseDataSnapshot) == "table" then
			baseSnapshot = self._fullBaseDataSnapshot
			Set.unionUpdate(keys, Set.fromKeys(self._fullBaseDataSnapshot))
		else
			baseSnapshot = {}
		end

		local diffSnapshot = {}
		for key, _ in keys do
			if self._writers[key] then
				diffSnapshot[key] = self._writers[key]:ComputeDiffSnapshot(incoming[key])
			else
				diffSnapshot[key] = self:_computeValueDiff(baseSnapshot[key], incoming[key])
			end
		end

		if not DataStoreSnapshotUtils.isEmptySnapshot(diffSnapshot) then
			return table.freeze(diffSnapshot)
		else
			if next(keys) then
				return nil -- No delta
			else
				return DataStoreDeleteToken
			end
		end
	else
		return self:_computeValueDiff(self._fullBaseDataSnapshot, incoming)
	end
end

function DataStoreWriter._computeValueDiff(self: DataStoreWriter, original, incoming)
	assert(original ~= DataStoreDeleteToken, "original cannot be DataStoreDeleteToken")
	assert(incoming ~= DataStoreDeleteToken, "incoming cannot be DataStoreDeleteToken")
	assert(not Symbol.isSymbol(original), "original should not be symbol")
	assert(not Symbol.isSymbol(incoming), "incoming should not be symbol")

	if original == incoming then
		return nil
	elseif original ~= nil and incoming == nil then
		return DataStoreDeleteToken
	elseif type(original) == "table" and type(incoming) == "table" then
		return self:_computeTableDiff(original, incoming)
	else
		return incoming
	end
end

function DataStoreWriter._computeTableDiff(self: DataStoreWriter, original, incoming)
	assert(type(original) == "table", "Bad original")
	assert(type(incoming) == "table", "Bad incoming")
	assert(not Symbol.isSymbol(original), "original should not be symbol")
	assert(not Symbol.isSymbol(incoming), "incoming should not be symbol")

	local keys = Set.union(Set.fromKeys(original), Set.fromKeys(incoming))

	local diffSnapshot = {}
	for key, _ in keys do
		diffSnapshot[key] = self:_computeValueDiff(original[key], incoming[key])
	end

	if not DataStoreSnapshotUtils.isEmptySnapshot(diffSnapshot) then
		return table.freeze(diffSnapshot)
	else
		return nil
	end
end

--[=[
	Set of user ids to write with the data (only applies to top-level writer)

	@param userIdList { number }
]=]
function DataStoreWriter.SetUserIdList(self: DataStoreWriter, userIdList: { number }?)
	assert(type(userIdList) == "table" or userIdList == nil, "Bad userIdList")

	self._userIdList = userIdList
end

--[=[
	User ids to associate with data

	@return userIdList { number }
]=]
function DataStoreWriter.GetUserIdList(self: DataStoreWriter): { number }?
	if self._userIdList == UNSET_TOKEN then
		return nil
	end

	return self._userIdList
end

function DataStoreWriter._writeMergeWriters(self: DataStoreWriter, original)
	local copy
	if Symbol.isSymbol(original) then
		copy = original
	elseif type(original) == "table" then
		copy = table.clone(original)
	else
		copy = original
	end

	if next(self._writers) ~= nil then
		-- Original was not a table. We need to swap to one.
		if type(copy) ~= "table" or Symbol.isSymbol(original) then
			copy = {}
		end

		-- Write our writers first...
		for key, writer in self._writers do
			local result = writer:WriteMerge(copy[key])
			if result == DataStoreDeleteToken then
				copy[key] = nil
			else
				copy[key] = result
			end
		end
	end

	-- Write our save data next
	if
		not Symbol.isSymbol(self._saveDataSnapshot)
		and type(self._saveDataSnapshot) == "table"
		and next(self._saveDataSnapshot) ~= nil
	then
		-- Original was not a table. We need to swap to one.
		if type(copy) ~= "table" then
			copy = {}
		end

		for key, value in self._saveDataSnapshot do
			if self._writers[key] then
				warn(
					string.format(
						"[DataStoreWriter._writeMergeWriters] - Overwriting key %q already saved as rawData with a writer with %q (was %q)",
						key,
						tostring(value),
						tostring(copy[key])
					)
				)
			end

			if value == DataStoreDeleteToken then
				copy[key] = nil
			else
				copy[key] = value
			end
		end
	end

	-- Handle empty table scenario..
	-- This would also imply our original is nil somehow...
	if not Symbol.isSymbol(copy) and type(copy) == "table" and next(copy) == nil then
		if type(self._saveDataSnapshot) ~= "table" then
			return nil
		end
	end

	return copy
end

--[=[
	Merges the new data into the original value

	@param original any
	@return any -- The original value
]=]
function DataStoreWriter.WriteMerge(self: DataStoreWriter, original)
	-- Prioritize save value first, followed by writers, followed by original value

	if self._saveDataSnapshot == DataStoreDeleteToken then
		return DataStoreDeleteToken
	elseif
		self._saveDataSnapshot == UNSET_TOKEN
		or self._saveDataSnapshot == nil
		or type(self._saveDataSnapshot) == "table"
	then
		return self:_writeMergeWriters(original)
	else
		-- Save data must be a boolean or something
		return self._saveDataSnapshot
	end
end

function DataStoreWriter.IsCompleteWipe(self: DataStoreWriter): boolean
	if self._saveDataSnapshot == UNSET_TOKEN then
		return false
	end

	if self._saveDataSnapshot == DataStoreDeleteToken then
		return true
	end

	return false
end

return DataStoreWriter