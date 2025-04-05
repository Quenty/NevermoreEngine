--!strict
--[=[
	Wraps MemoryService APIs
	@class MemoryStoreUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local MemoryStoreUtils = {}

local DEBUG_QUEUE = false

--[=[
	Promises to add from the queue
	@param queue MemoryStoreQueue
	@param value any
	@param expirationSeconds number
	@param priority number?
	@return Promise
]=]
function MemoryStoreUtils.promiseAdd(
	queue: MemoryStoreQueue,
	value: any,
	expirationSeconds: number,
	priority: number?
): Promise.Promise<()>
	assert(typeof(queue) == "Instance" and queue:IsA("MemoryStoreQueue"), "Bad queue")
	assert(type(expirationSeconds) == "number", "Bad expirationSeconds")
	assert(type(priority) == "number" or priority == nil, "Bad priority")

	return Promise.spawn(function(resolve, reject)
		if DEBUG_QUEUE then
			print(string.format("[MemoryStoreUtils.promiseAdd] - Queuing %q", HttpService:JSONEncode(value)))
		end

		local ok, err = pcall(function()
			queue:AddAsync(value, expirationSeconds, priority)
		end)

		if not ok then
			if DEBUG_QUEUE then
				warn(string.format("Failed to queue due to %q", err or "nil"))
			end
			return reject(err or "[MemoryStoreUtils.promiseAdd] - Failed to AddAsync to the queue")
		end
		return resolve()
	end)
end

--[=[
	Promises to read from the queue
	@param queue MemoryStoreQueue
	@param count number
	@param allOrNothing boolean
	@param waitTimeout number
	@return Promise<(any?, string?)>
]=]
function MemoryStoreUtils.promiseRead(
	queue: MemoryStoreQueue,
	count: number,
	allOrNothing: boolean,
	waitTimeout: number
): Promise.Promise<(any?, string?)>
	assert(typeof(queue) == "Instance" and queue:IsA("MemoryStoreQueue"), "Bad queue")
	assert(type(count) == "number", "Bad count")
	assert(type(allOrNothing) == "boolean", "Bad allOrNothing")
	assert(type(waitTimeout) == "number", "Bad waitTimeout")

	return Promise.spawn(function(resolve, reject)
		if DEBUG_QUEUE then
			print("[MemoryStoreUtils.promiseRead] - Reading queue")
		end

		local values, removeId
		local ok, err = pcall(function()
			values, removeId = queue:ReadAsync(count, allOrNothing, waitTimeout)
		end)

		if not ok then
			if DEBUG_QUEUE then
				print("[MemoryStoreUtils.promiseRead] - Read from queue", ok, values, removeId)
				warn(string.format("[MemoryStoreUtils.promiseRead] - Failed to read queue due to %q", err or "nil"))
			end

			return reject(err or "[MemoryStoreUtils.promiseRead] - Failed to ReadAsync from the queue")
		end

		if DEBUG_QUEUE then
			print("[MemoryStoreUtils.promiseRead] - Read from queue", values, removeId)
		end

		return resolve(values, removeId)
	end)
end

--[=[
	Promises to remove from the queue
	@param queue MemoryStoreQueue
	@param id string
	@return Promise
]=]
function MemoryStoreUtils.promiseRemove(queue: MemoryStoreQueue, id: string): Promise.Promise<()>
	assert(typeof(queue) == "Instance" and queue:IsA("MemoryStoreQueue"), "Bad queue")
	assert(type(id) == "string", "Bad id")

	return Promise.spawn(function(resolve, reject)
		if DEBUG_QUEUE then
			print(string.format("[MemoryStoreUtils.promiseRemove] - Removing %q", HttpService:JSONEncode(id)))
		end

		local ok, err = pcall(function()
			queue:RemoveAsync(id)
		end)

		if not ok then
			if DEBUG_QUEUE then
				warn(string.format("Failed to remove queue id %q due to %q", id, err or "nil"))
			end

			return reject(err or "[MemoryStoreUtils.promiseRemove] - Failed to RemoveAsync from the queue")
		end
		return resolve()
	end)
end

return MemoryStoreUtils
