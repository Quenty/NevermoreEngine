--- Utility methods to interactive with DataStores
-- @module DataStorePromises

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local DataStoreService = game:GetService("DataStoreService")

local DataStorePromises = {}

function DataStorePromises.promiseDataStore(name, scope)
	assert(type(name) == "string", "Bad name")
	assert(type(scope) == "string", "Bad scope")

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
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")

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
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")
	assert(type(updateFunc) == "function", "Bad updateFunc")

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
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")

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
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")
	assert(type(delta) == "number" or delta == nil, "Bad delta")

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
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")

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