--[=[
	Utility methods to interactive with Roblox datastores.
	@server
	@class DataStorePromises
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local DataStoreService = game:GetService("DataStoreService")

local DataStorePromises = {}

--[=[
	Promises a Roblox datastore object with the name and scope. Generally only fails
	when you haven't published the place.
	@param name string
	@param scope string
	@return Promise<DataStore>
]=]
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

--[=[
	Wraps :GetAsync() in a promise
	@param robloxDataStore DataStore
	@param key string
	@return Promise<T>
]=]
function DataStorePromises.getAsync(robloxDataStore, key)
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")

	return Promise.spawn(function(resolve, reject)
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

--[=[
	Wraps :UpdateAsync() in a promise
	@param robloxDataStore DataStore
	@param key string
	@param updateFunc (T) -> T?
	@return Promise<boolean>
]=]

function DataStorePromises.updateAsync(robloxDataStore, key, updateFunc)
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")
	assert(type(updateFunc) == "function", "Bad updateFunc")

	return Promise.spawn(function(resolve, reject)
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

--[=[
	Wraps :SetAsync() in a promise
	@param robloxDataStore DataStore
	@param key string
	@param value string
	@return Promise<boolean>
]=]
function DataStorePromises.setAsync(robloxDataStore, key, value)
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			robloxDataStore:SetAsync(key, value)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(true)
	end)
end

--[=[
	Wraps :IncrementAsync() in a promise
	@param robloxDataStore DataStore
	@param key string
	@param delta number
	@return Promise<boolean>
]=]
function DataStorePromises.promiseIncrementAsync(robloxDataStore, key, delta)
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")
	assert(type(delta) == "number" or delta == nil, "Bad delta")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			robloxDataStore:IncrementAsync(key, delta)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(true)
	end)
end

--[=[
	Wraps :RemoveAsync() in a promise
	@param robloxDataStore DataStore
	@param key string
	@return Promise<boolean>
]=]
function DataStorePromises.removeAsync(robloxDataStore, key)
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")

	return Promise.spawn(function(resolve, reject)
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