---
-- @module RemoteFunctionUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local RemoteFunctionUtils = {}

function RemoteFunctionUtils.promiseInvokeServer(remoteFunction, ...)
	assert(typeof(remoteFunction) == "Instance" and remoteFunction:IsA("RemoteFunction"))

	local args = table.pack(...)

	return Promise.defer(function(resolve, reject)
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

		return resolve(table.pack(results, 1, results.n))
	end)
end

return RemoteFunctionUtils