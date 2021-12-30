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

	self._rawSetData = {}
	self._writers = {}

	return self
end

--[=[
	Sets the ray data to write
	@param data table
]=]
function DataStoreWriter:SetRawData(data)
	self._rawSetData = Table.deepCopy(data)
end

--[=[
	Adds a recursive child writer to use at the key `name`
	@param name string
	@param writer DataStoreWriter
]=]
function DataStoreWriter:AddWriter(name, writer)
	assert(type(name) == "string", "Bad name")
	assert(not self._writers[name], "Writer already exists for name")
	assert(writer, "Bad writer")

	self._writers[name] = writer
end

--[=[
	Merges the new data into the original value

	@param original table?
	@return table -- The original table
]=]
function DataStoreWriter:WriteMerge(original)
	original = original or {}

	for key, value in pairs(self._rawSetData) do
		if value == DataStoreDeleteToken then
			original[key] = nil
		else
			original[key] = value
		end
	end

	for key, writer in pairs(self._writers) do
		if self._rawSetData[key] ~= nil then
			warn(("[DataStoreWriter.WriteMerge] - Overwritting key %q already saved as rawData with a writer")
				:format(tostring(key)))
		end

		local result = writer:WriteMerge(original[key])
		if result == DataStoreDeleteToken then
			original[key] = nil
		else
			original[key] = result
		end
	end

	return original
end

return DataStoreWriter