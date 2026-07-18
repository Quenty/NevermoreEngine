--!strict
--[=[
	Wraps a datastore-operation failure during a session-locked load so it is distinguishable from
	lock contention. Op failures (e.g. 509) will not resolve by retrying -- Roblox already retries
	internally -- so we fail fast rather than grinding the acquire backoff, while lock contention (a
	successful op that returns a locked profile) keeps retrying. The original error is preserved.

	@server
	@class DataStoreNonRetryableLoadError
]=]

local DataStoreNonRetryableLoadError = {}
DataStoreNonRetryableLoadError.ClassName = "DataStoreNonRetryableLoadError"
DataStoreNonRetryableLoadError.__index = DataStoreNonRetryableLoadError

export type DataStoreNonRetryableLoadError = typeof(setmetatable(
	{} :: {
		innerError: any,
	},
	DataStoreNonRetryableLoadError
))

function DataStoreNonRetryableLoadError.__tostring(self: DataStoreNonRetryableLoadError): string
	return tostring(self.innerError)
end

--[=[
	Wraps an inner error so it is treated as non-retryable during a session-locked load.

	@param innerError any
	@return DataStoreNonRetryableLoadError
]=]
function DataStoreNonRetryableLoadError.new(innerError: any): DataStoreNonRetryableLoadError
	return setmetatable({ innerError = innerError }, DataStoreNonRetryableLoadError)
end

--[=[
	Returns true if the given error is a [DataStoreNonRetryableLoadError].

	@param err any
	@return boolean
]=]
function DataStoreNonRetryableLoadError.isNonRetryableLoadError(err: any): boolean
	return type(err) == "table" and getmetatable(err) == DataStoreNonRetryableLoadError
end

--[=[
	Returns the original inner error if the given error is a [DataStoreNonRetryableLoadError],
	otherwise returns the error unchanged.

	@param err any
	@return any
]=]
function DataStoreNonRetryableLoadError.unwrapLoadError(err: any): any
	if DataStoreNonRetryableLoadError.isNonRetryableLoadError(err) then
		return err.innerError
	end
	return err
end

return DataStoreNonRetryableLoadError
