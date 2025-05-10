--!strict
--[=[
	Utility functions to wrap invoking a remote function with a promise
	@class RemoteFunctionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

local RemoteFunctionUtils = {}

--[=[
	Invokes the server with the remote function call.
	@param remoteFunction RemoteFunction
	@param ... any
	@return Promise<T>
]=]
function RemoteFunctionUtils.promiseInvokeServer(remoteFunction: RemoteFunction, ...): Promise.Promise<any>
	assert(typeof(remoteFunction) == "Instance" and remoteFunction:IsA("RemoteFunction"), "Bad remoteFunction")

	local args = table.pack(...)

	return Promise.spawn(function(resolve, reject)
		local results
		local ok, err = pcall(function()
			results = table.pack(remoteFunction:InvokeServer(table.unpack(args, 1, args.n)))
		end)

		if not ok then
			return reject(err or "Failed to invoke server from RemoteFunction")
		end

		if not results then
			return reject("Failed to get results from RemoteFunction")
		end

		return resolve(table.unpack(results, 1, results.n))
	end)
end

--[=[
	Invokes the client with the remote function call.
	@param remoteFunction RemoteFunction
	@param player Instance
	@param ... any
	@return Promise<T>
]=]
function RemoteFunctionUtils.promiseInvokeClient(
	remoteFunction: RemoteFunction,
	player: Player,
	...
): Promise.Promise<any>
	assert(typeof(remoteFunction) == "Instance" and remoteFunction:IsA("RemoteFunction"), "Bad remoteFunction")

	local args = table.pack(...)

	return Promise.spawn(function(resolve, reject)
		local results
		local ok, err = pcall(function()
			results = table.pack(remoteFunction:InvokeClient(player, table.unpack(args, 1, args.n)))
		end)

		if not ok then
			return reject(err or "Failed to invoke clientfrom RemoteFunction")
		end

		if not results then
			return reject("Failed to get results from RemoteFunction")
		end

		return resolve(table.unpack(results, 1, results.n))
	end)
end

--[=[
	Invokes the server with the remote function call.
	@param bindableFunction RemoteFunction
	@param ... any
	@return Promise<T>
]=]
function RemoteFunctionUtils.promiseInvokeBindableFunction(
	bindableFunction: BindableFunction,
	...
): Promise.Promise<any>
	assert(typeof(bindableFunction) == "Instance" and bindableFunction:IsA("BindableFunction"), "Bad bindableFunction")

	local args = table.pack(...)

	return Promise.spawn(function(resolve, reject)
		local results
		local ok, err = pcall(function()
			results = table.pack(bindableFunction:Invoke(table.unpack(args, 1, args.n)))
		end)

		if not ok then
			return reject(err or "Failed to invoke from BindableFunction")
		end

		if not results then
			return reject("Failed to get results from BindableFunction")
		end

		return resolve(table.unpack(results, 1, results.n))
	end)
end

--[=[
	Converts a promise result into a promise

	@param ok boolean
	@param ... any
	@return Promise<T>
]=]
function RemoteFunctionUtils.fromPromiseYieldResult(ok: boolean, ...): Promise.Promise<any>
	if ok then
		return ...
	else
		local n = select("#", ...)
		if n == 0 then
			return Promise.rejected("Failed to get result from RemoteFunction")
		else
			return Promise.rejected(...)
		end
	end
end

return RemoteFunctionUtils
