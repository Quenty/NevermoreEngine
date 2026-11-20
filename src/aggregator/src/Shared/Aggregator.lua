--!strict
--[=[
	Aggregates all requests into one big send request to deduplicate the request

	@class Aggregator
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local LRUCache = require("LRUCache")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")

local Aggregator = setmetatable({}, BaseObject)
Aggregator.ClassName = "Aggregator"
Aggregator.__index = Aggregator

export type PromiseBulkQuery<T> = ({ number }) -> Promise.Promise<T>

export type Aggregator<T> =
	typeof(setmetatable(
		{} :: {
			_debugName: string,
			_promiseBatchQuery: ({ number }) -> Promise.Promise<T>,
			_promisesLruCache: any,
			_maxBatchSize: number,
			_unsentCount: number,
			_unsentPromises: { [number]: Promise.Promise<T> },
			_batchDelay: number,
			_minSendInterval: number,
			_lastSendAt: number,
		},
		{} :: typeof({ __index = Aggregator })
	))
	& BaseObject.BaseObject

--[=[
	Creates a new aggregator that aggregates promised results together

	@param debugName string
	@param promiseBulkQuery ({ number }) -> Promise<T>

	@return Aggregator<T>
]=]
function Aggregator.new<T>(debugName: string, promiseBulkQuery: PromiseBulkQuery<T>): Aggregator<T>
	assert(type(debugName) == "string", "Bad debugName")

	local self: Aggregator<T> = setmetatable(BaseObject.new() :: any, Aggregator)

	self._debugName = debugName
	self._promiseBatchQuery = assert(promiseBulkQuery, "No promiseBulkQuery")

	self._promisesLruCache = LRUCache.new(2000)

	self._maxBatchSize = 200
	self._unsentCount = 0
	self._unsentPromises = {}

	self._batchDelay = 0.1
	self._minSendInterval = 0
	self._lastSendAt = -math.huge

	return self
end

--[=[
	Sets how long requests are collected before a batch is sent, and the least time between two
	sends. Requests over the batch size wait for the next send. Useful for endpoints that throttle
	frequent requests. Defaults to 0.1 seconds and no minimum.

	@param batchDelay number
	@param minSendInterval number
]=]
function Aggregator.SetBatchTiming<T>(self: Aggregator<T>, batchDelay: number, minSendInterval: number): ()
	assert(type(batchDelay) == "number" and batchDelay >= 0, "Bad batchDelay")
	assert(type(minSendInterval) == "number" and minSendInterval >= 0, "Bad minSendInterval")

	self._batchDelay = batchDelay
	self._minSendInterval = minSendInterval
end

--[=[
	Sets the max batch size
	@param maxBatchSize number
]=]
function Aggregator.SetMaxBatchSize<T>(self: Aggregator<T>, maxBatchSize: number): ()
	assert(type(maxBatchSize) == "number", "Bad maxBatchSize")
	assert(self._unsentCount == 0, "Cannot set while unsent values exist")

	self._maxBatchSize = maxBatchSize
end

--[=[
	@param id number
	@return Promise<T>
]=]
function Aggregator.Promise<T>(self: Aggregator<T>, id: number): Promise.Promise<T>
	assert(type(id) == "number", "Bad id")

	local found = self._promisesLruCache:get(id)
	if found then
		return found
	end

	local promise = Promise.new()

	self._unsentPromises[id] = promise
	self._unsentCount = self._unsentCount + 1
	self._promisesLruCache:set(id, promise)

	self:_queueBatchRequests()

	return promise
end

--[=[
	Observes the aggregated data

	@param id number
	@return Observable<T>
]=]
function Aggregator.Observe<T>(self: Aggregator<T>, id: number): Observable.Observable<T>
	assert(type(id) == "number", "Bad id")

	return Rx.fromPromise(self:Promise(id)) :: any
end

function Aggregator._sendBatchedPromises<T>(self: Aggregator<T>, promiseMap)
	assert(promiseMap, "No promiseMap")

	local idList = {}
	local unresolvedMap = {}
	for id, promise in promiseMap do
		table.insert(idList, id)
		unresolvedMap[id] = promise
	end

	if #idList == 0 then
		return
	end

	assert(#idList <= self._maxBatchSize, "Too many idList sent")

	-- Don't cache failures: asking for a failed id again should retry it.
	local function forget(id, promise)
		if self._promisesLruCache:get(id) == promise then
			self._promisesLruCache:delete(id)
		end
	end

	self._lastSendAt = os.clock()
	self._maid:GivePromise(self._promiseBatchQuery(idList)):Then(function(result)
		assert(type(result) == "table", "Bad result")

		for _, data in result do
			assert(type(data.Id) == "number", "Bad result[?].Id")

			if unresolvedMap[data.Id] then
				unresolvedMap[data.Id]:Resolve(data)
				unresolvedMap[data.Id] = nil
			end
		end

		-- Reject other ones
		for id, promise in unresolvedMap do
			forget(id, promise)
			promise:Reject(string.format("[Aggregator] %s failed to get result for id %d", self._debugName, id))
		end
	end, function(err, ...)
		local text = string.format("[Aggregator] %s failed to get bulk result - %q", self._debugName, tostring(err))

		for id, item in unresolvedMap do
			forget(id, item)
			item:Reject(text, ...)
		end
	end)
end

-- Takes up to one batch's worth of the unsent requests off the queue.
function Aggregator._resetQueue<T>(self: Aggregator<T>)
	local promiseMap = {}
	local taken = 0
	for id, promise in self._unsentPromises do
		if taken >= self._maxBatchSize then
			break
		end
		promiseMap[id] = promise
		taken += 1
	end
	for id in promiseMap do
		self._unsentPromises[id] = nil
	end
	self._unsentCount -= taken
	self._maid._queue = nil

	return promiseMap
end

function Aggregator._queueBatchRequests<T>(self: Aggregator<T>): ()
	local sinceLast = os.clock() - self._lastSendAt
	if self._unsentCount >= self._maxBatchSize and sinceLast >= self._minSendInterval then
		self._maid._queue = nil
		self:_sendBatchedPromises(self:_resetQueue())
		if self._unsentCount > 0 then
			self:_queueBatchRequests()
		end
		return
	end

	if self._maid._queue then
		return
	end

	local wait = math.max(self._batchDelay, self._minSendInterval - sinceLast)
	self._maid._queue = task.delay(wait, function()
		task.spawn(function()
			self:_sendBatchedPromises(self:_resetQueue())
			-- More than one batch was waiting: the rest goes after the interval.
			if self._unsentCount > 0 then
				self:_queueBatchRequests()
			end
		end)
	end)
end

return Aggregator
