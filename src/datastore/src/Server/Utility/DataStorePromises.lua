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
	Promises a Roblox datastore object with the name and scope. Generally only fails
	when you haven't published the place.
	@param name string
	@param scope string
	@return Promise<OrderedDataStore>
]=]
function DataStorePromises.promiseOrderedDataStore(name, scope)
	assert(type(name) == "string", "Bad name")
	assert(type(scope) == "string", "Bad scope")

	return Promise.new(function(resolve, reject)
		local result = nil
		local ok, err = pcall(function()
			result = DataStoreService:GetOrderedDataStore(name, scope)
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
		local dataStoreKeyInfo = nil
		local ok, err = pcall(function()
			result, dataStoreKeyInfo = robloxDataStore:GetAsync(key)
		end)
		if not ok then
			return reject(err)
		end
		return resolve(result, dataStoreKeyInfo)
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
	@param userIds { number } -- Associated userIds
	@return Promise<boolean>
]=]
function DataStorePromises.setAsync(robloxDataStore, key, value, userIds)
	assert(typeof(robloxDataStore) == "Instance", "Bad robloxDataStore")
	assert(type(key) == "string", "Bad key")
	assert(type(userIds) == "table" or userIds == nil, "Bad userIds")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			robloxDataStore:SetAsync(key, value, userIds)
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

--[=[
	Returns a DataStorePages object. The sort order is determined by ascending,
	the length of each page by pageSize, and minValue/maxValue are
	optional parameters which filter the results.

	@param orderedDataStore OrderedDataStore
	@param ascending boolean
	@param pagesize int
	@param minValue number?
	@param maxValue number?
	@return Promise<DataStorePages>
]=]
function DataStorePromises.promiseSortedPagesAsync(orderedDataStore, ascending, pagesize, minValue, maxValue)
	assert(typeof(orderedDataStore) == "Instance" and orderedDataStore:IsA("OrderedDataStore"), "Bad orderedDataStore")
	assert(type(ascending) == "boolean", "Bad ascending")
	assert(type(pagesize) == "number", "Bad entries")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = orderedDataStore:GetSortedAsync(ascending, pagesize, minValue, maxValue)
		end)
		if not ok then
			return reject(err)
		end
		if typeof(result) ~= "Instance" then
			return reject(err)
		end

		return resolve(result)
	end)
end

--[=[
	@interface OrderedDataStoreEntry
	.key any
	.value any
	@within DataStorePromises
]=]

--[=[
	Returns a DataStorePages object. The sort order is determined by ascending,
	the length of each page by pageSize, and minValue/maxValue are
	optional parameters which filter the results.

	@param orderedDataStore OrderedDataStore
	@param ascending boolean
	@param pagesize int
	@param entries int -- Number of entries to pull
	@param minValue number?
	@param maxValue number?
	@return Promise<OrderedDataStoreEntry>
]=]
function DataStorePromises.promiseOrderedEntries(orderedDataStore, ascending, pagesize, entries, minValue, maxValue)
	assert(typeof(orderedDataStore) == "Instance" and orderedDataStore:IsA("OrderedDataStore"), "Bad orderedDataStore")
	assert(type(ascending) == "boolean", "Bad ascending")
	assert(type(entries) == "number", "Bad entries")

	return DataStorePromises.promiseSortedPagesAsync(orderedDataStore, ascending, pagesize, minValue, maxValue)
		:Then(function(dataStorePages)
			return Promise.spawn(function(resolve, reject)
				local results = {}
				local index = 0

				while index < entries do
					local initialIndex = index

					for _, dataStoreEntry in pairs(dataStorePages:GetCurrentPage()) do
						table.insert(results, dataStoreEntry)
						index = index + 1
						if index >= entries then
							break
						end
					end

					-- Increment to next page if we need to/can
					if initialIndex == index then
						break -- no change
					elseif dataStorePages.IsFinished then
						break -- nothing more to pull
					elseif index < entries then
						-- try to pull
						local ok, err = pcall(function()
							dataStorePages:AdvanceToNextPageAsync()
						end)
						if not ok then
							return reject(err)
						end
					end
				end

				return resolve(results)
			end)
		end)
end

return DataStorePromises