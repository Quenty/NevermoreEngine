--- Utility methods to interactive with DataStores
-- @module DataStorePromises

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local DataStorePromises = {}

function DataStorePromises.GetAsync(robloxDataStore, key)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")

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

function DataStorePromises.UpdateAsync(robloxDataStore, key, updateFunc)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")
	assert(type(updateFunc) == "function")

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

function DataStorePromises.SetAsync(robloxDataStore, key, value)
	assert(typeof(robloxDataStore) == "Instance")
	assert(type(key) == "string")

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

return DataStorePromises