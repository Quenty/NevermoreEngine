--- Utility methods to interactive with DataStores
-- @module DataStorePromises

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local DataStoreService = game:GetService("DataStoreService")

local DataStorePromises = {}

function DataStorePromises.promiseDataStore(name, scope)
	assert(type(name) == "string")
	assert(type(scope) == "string")

	return Promise.new(function(resolve, reject)
		local result = nil
		local ok, err = pcall(function()
			result = DataStoreService:GetDataStore(name, scope)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(result)
	end)

end

function DataStorePromises.getAsync(robloxDataStore, key)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")

	return Promise.defer(function(resolve, reject)
		local result = nil
		local ok, err = pcall(function()
			result = robloxDataStore:GetAsync(key)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(result)
	end)
end

function DataStorePromises.updateAsync(robloxDataStore, key, updateFunc)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")
	assert(type(updateFunc) == "function")

	return Promise.defer(function(resolve, reject)
		local result = nil
		local ok, err = pcall(function()
			result = { robloxDataStore:UpdateAsync(key, updateFunc) }
		end)
		if not ok then
			return reject(err)
		end
		if not result then
			return reject("No result loaded")
		end
		return resolve(unpack(result))
	end)
end

function DataStorePromises.setAsync(robloxDataStore, key, value)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")

	return Promise.defer(function(resolve, reject)
		local ok, err = pcall(function()
			robloxDataStore:SetAsync(key, value)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(true)
	end)
end

function DataStorePromises.promiseIncrementAsync(robloxDataStore, key, delta)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")
	assert(type(delta) == "number" or delta == nil)

	return Promise.defer(function(resolve, reject)
		local ok, err = pcall(function()
			robloxDataStore:IncrementAsync(key, delta)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(true)
	end)
end

function DataStorePromises.removeAsync(robloxDataStore, key)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")

	return Promise.defer(function(resolve, reject)
		local ok, err = pcall(function()
			robloxDataStore:RemoveAsync(key)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(true)
	end)
end

return DataStorePromises