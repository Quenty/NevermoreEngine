--!strict
--[=[
	Utility methods to interactive with Roblox datastores.
	@server
	@class DataStorePromises
]=]

local require = require(script.Parent.loader).load(script)

local DataStoreService = game:GetService("DataStoreService")

local Promise = require("Promise")
local PagesUtils = require("PagesUtils")
local Table = require("Table")

local DataStorePromises = {}

export type RobloxDataStore = DataStore

--[=[
	Promises a Roblox datastore object with the name and scope. Generally only fails
	when you haven't published the place.
	@param name string
	@param scope string
	@return Promise<DataStore>
]=]
function DataStorePromises.promiseDataStore(name: string, scope: string): Promise.Promise<DataStore>
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
function DataStorePromises.promiseOrderedDataStore(name: string, scope: string): Promise.Promise<OrderedDataStore>
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
function DataStorePromises.getAsync<T>(robloxDataStore: DataStore, key: string): Promise.Promise<T>
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
	@return Promise<T>
]=]

function DataStorePromises.updateAsync<T>(
	robloxDataStore: DataStore,
	key: string,
	updateFunc: (T, DataStoreKeyInfo) -> T?
): Promise.Promise<(T, DataStoreKeyInfo)>
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
function DataStorePromises.setAsync(
	robloxDataStore: DataStore,
	key,
	value: string,
	userIds: { number }?
): Promise.Promise<boolean>
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
function DataStorePromises.promiseIncrementAsync(
	robloxDataStore: DataStore,
	key: string,
	delta: number
): Promise.Promise<boolean>
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
function DataStorePromises.removeAsync(robloxDataStore: DataStore, key: string): Promise.Promise<boolean>
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
function DataStorePromises.promiseSortedPagesAsync(
	orderedDataStore: OrderedDataStore,
	ascending: boolean,
	pagesize: number,
	minValue: number?,
	maxValue: number?
): Promise.Promise<DataStorePages>
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
export type OrderedDataStoreEntry = {
	key: string,
	value: any,
}

local function toMap(data: { OrderedDataStoreEntry })
	local keys = {}
	for _, item in data do
		keys[item.key] = item.value
	end
	return keys
end

local function areEquivalentPageData(data: { OrderedDataStoreEntry }, otherData: { OrderedDataStoreEntry }): boolean
	local map = toMap(data)
	local otherMap = toMap(otherData)

	return Table.deepEquivalent(map, otherMap)
end


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
function DataStorePromises.promiseOrderedEntries(orderedDataStore: OrderedDataStore, ascending: boolean, pagesize: number, entries: number, minValue: number?, maxValue: number?): Promise.Promise<OrderedDataStoreEntry>
	assert(typeof(orderedDataStore) == "Instance" and orderedDataStore:IsA("OrderedDataStore"), "Bad orderedDataStore")
	assert(type(ascending) == "boolean", "Bad ascending")
	assert(type(entries) == "number", "Bad entries")

	-- stylua: ignore
	return DataStorePromises.promiseSortedPagesAsync(orderedDataStore, ascending, pagesize, minValue, maxValue)
		:Then(function(dataStorePages: DataStorePages)
			return Promise.spawn(function(resolve, reject)
				local resultList = {}

				local pageData: any? = dataStorePages:GetCurrentPage()
				while pageData do
					for _, data in pageData do
						if #resultList < entries then
							table.insert(resultList, data)
						else
							break
						end
					end

					local lastPageData = pageData
					pageData = nil

					if #resultList >= entries then
						break
					end

					if not dataStorePages.IsFinished then
						local ok, err = PagesUtils.promiseAdvanceToNextPage(dataStorePages):Yield()
						if not ok then
							return reject(string.format("Failed to advance to next page due to %s", tostring(err)))
						end

						pageData = err
					end

					-- https://devforum.roblox.com/t/ordereddatastore-pages-object-is-never-isfinished-resulting-in-finite-loops-when-n-0/3558372
					if pageData and areEquivalentPageData(lastPageData, pageData) then
						break
					end
				end

				return resolve(resultList)
			end)
		end)
end

return DataStorePromises