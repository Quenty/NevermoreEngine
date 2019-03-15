--- Utility methods to interactive with DataStores
-- @module DataStorePromises

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local DataStorePromises = {}

function DataStorePromises.GetAsync(datastore, key)
	assert(datastore)
	assert(type(key) == "string")

	return Promise.new(function(resolve, reject)
		local result = nil
		local ok, err = pcall(function()
			result = datastore:GetAsync(key)
		end)
		if not ok then
			return reject(err)
		end
		if not result then
			return reject("No result loaded")
		end
		return resolve(result)
	end)
end

function DataStorePromises.UpdateAsync(datastore, key, updateFunc)
	assert(datastore)
	assert(type(key) == "string")
	assert(type(updateFunc) == "function")

	return Promise.new(function(resolve, reject)
		local result = nil
		local ok, err = pcall(function()
			result = { datastore:UpdateAsync(key, updateFunc) }
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


return DataStorePromises