--[=[
	Captures a snapshot of data to write and then merges it with the original.
	@server
	@class DataStoreWriter
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")
local DataStoreDeleteToken = require("DataStoreDeleteToken")

local DataStoreWriter = {}
DataStoreWriter.ClassName = "DataStoreWriter"
DataStoreWriter.__index = DataStoreWriter

--[=[
	Constructs a new DataStoreWriter. In general, you will not use this API directly.

	@return DataStoreWriter
]=]
function DataStoreWriter.new()
	local self = setmetatable({}, DataStoreWriter)

	self._dataToSaveThisLevel = {}
	self._writers = {}

	-- Merging
	self._diffData = {}
	self._baseData = {}

	return self
end

--[=[
	Sets the ray data to write
	@param data table
]=]
function DataStoreWriter:SetDataToSave(data)
	self._dataToSaveThisLevel = Table.deepCopy(data)
end

function DataStoreWriter:GetDataToSave()
	return self._dataToSaveThisLevel
end

function DataStoreWriter:GetSubWritersMap()
	return self._writers
end

function DataStoreWriter:SetBaseData(baseData)
	self._baseData = Table.deepCopy(baseData)
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

function DataStoreWriter:GetWriter(name)
	assert(type(name) == "string", "Bad name")

	return self._writers[name]
end

function DataStoreWriter:StoreDifference(incoming)
	for key, value in pairs(incoming) do
		if self._writers[key] ~= nil then
			self._writers[key]:StoreDifference(value)
		end

		-- TODO: Handle deletes
		if self._baseData[key] ~= value then
			self._diffData[key] = value
		end
	end
end

function DataStoreWriter:GetDiffData()
	return self._diffData
end

--[=[
	Merges the new data into the original value

	@param original table?
	@param doMergeNewData boolean
	@return table -- The original table
]=]
function DataStoreWriter:WriteMerge(original, doMergeNewData)
	original = original or {}

	for key, value in pairs(self._dataToSaveThisLevel) do
		if value == DataStoreDeleteToken then
			original[key] = nil
		else
			original[key] = value
		end
	end

	for key, writer in pairs(self._writers) do
		if self._dataToSaveThisLevel[key] ~= nil then
			warn(("[DataStoreWriter.WriteMerge] - Overwritting key %q already saved as rawData with a writer")
				:format(tostring(key)))
		end

		local result = writer:WriteMerge(original[key], doMergeNewData)
		if result == DataStoreDeleteToken then
			original[key] = nil
		else
			original[key] = result
		end
	end

	return original
end

return DataStoreWriter