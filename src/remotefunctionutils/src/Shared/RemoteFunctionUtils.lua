--- Utility functions to wrap invoking a remote function with a promise
-- @module RemoteFunctionUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local RemoteFunctionUtils = {}

function RemoteFunctionUtils.promiseInvokeServer(remoteFunction, ...)
	assert(typeof(remoteFunction) == "Instance" and remoteFunction:IsA("RemoteFunction"), "Bad remoteFunction")

	local args = table.pack(...)

	return Promise.spawn(function(resolve, reject)
		local results
		local ok, err = pcall(function()
			results = table.pack(remoteFunction:InvokeServer(table.unpack(args, 1, args.n)))
		end)

		if not ok then
			return reject(err or "Failed to invoke server")
		end

		if not results then
			return reject("Failed to get results somehow")
		end

		return resolve(table.unpack(results, 1, results.n))
	end)
end

return RemoteFunctionUtils