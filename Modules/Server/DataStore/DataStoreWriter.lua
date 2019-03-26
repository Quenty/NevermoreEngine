--- Captures a snapshot of data to write and then merges it with the original
-- @classmod DataStoreWriter

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")
local DataStoreDeleteToken = require("DataStoreDeleteToken")

local DataStoreWriter = {}
DataStoreWriter.ClassName = "DataStoreWriter"
DataStoreWriter.__index = DataStoreWriter

function DataStoreWriter.new()
	local self = setmetatable({}, DataStoreWriter)

	self._rawSetData = {}
	self._writers = {}

	return self
end

function DataStoreWriter:SetRawData(data)
	self._rawSetData = Table.DeepCopy(data)
end

function DataStoreWriter:AddWriter(name, value)
	assert(type(name) == "string")
	assert(not self._writers[name])
	assert(value)

	self._writers[name] = value
end

-- Do merge here
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