--- Stores very large strings into the datastore
-- @classmod ChunkDataStore

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpService = game:GetService("HttpService")

local ChunkUtils = require("ChunkUtils")
local DataStorePromises = require("DataStorePromises")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")

local CHUNK_SIZE = 1000 -- 260000 - 100

local ChunkDataStore = {}
ChunkDataStore.ClassName = "ChunkDataStore"
ChunkDataStore.__index = ChunkDataStore

function ChunkDataStore.new(datastore)
	local self = setmetatable({}, ChunkDataStore)

	self._datastore = datastore or error("No datastore")

	return self
end

function ChunkDataStore:WriteEntry(largeString)
	local promises = {}
	local keys = {}

	for chunk in ChunkUtils.chunkStr(largeString, CHUNK_SIZE) do
		local key = HttpService:GenerateGUID(false)
		table.insert(keys, key)
		table.insert(promises, DataStorePromises.SetAsync(self._datastore, key, chunk))
	end

	return PromiseUtils.all(promises):Then(function(...)
		return {
			EntryVersion = 1;
			FileSize = #largeString;
			Keys = keys;
		}
	end)
end

function ChunkDataStore:LoadEntry(entry)
	assert(type(entry) == "table")
	assert(type(entry.EntryVersion) == "number")
	assert(type(entry.FileSize) == "number")
	assert(type(entry.Keys) == "table")

	return self:_loadChunks(entry.Keys):Then(function(chunks)
		return self:_decodeChunksToStr(chunks, entry.FileSize)
	end)
end

function ChunkDataStore:_loadChunks(keys)
	local promises = {}
	for _, item in pairs(keys) do
		table.insert(promises, self:_loadChunk(item))
	end

	return PromiseUtils.all(promises):Then(function(...)
		return {...}
	end)
end

function ChunkDataStore:_decodeChunksToStr(chunks, expectedSize)
	return Promise.new(function(resolve, reject)
		for index, item in pairs(chunks) do
			if type(item) ~= "string" then
				reject("Failed to load chunk #" .. index)
				return
			end
		end

		local total = table.concat(chunks, "")

		if #total ~= expectedSize then
			reject(("Combined chunks is %d, expectd %d"):format(#total, expectedSize))
			return
		end

		resolve(total)
		return
	end)
end

function ChunkDataStore:_loadChunk(key)
	if type(key) ~= "string" then
		return Promise.rejected("Key is not a string")
	end

	return DataStorePromises.GetAsync(self._datastore, key)
end

return ChunkDataStore