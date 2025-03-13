--[=[
	Aggregates all requests into one big send request to deduplicate the request

	@class Aggregator
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local Rx = require("Rx")
local LRUCache = require("LRUCache")

local Aggregator = setmetatable({}, BaseObject)
Aggregator.ClassName = "Aggregator"
Aggregator.__index = Aggregator

--[=[
	Creates a new aggregator that aggregates promised results together

	@param debugName string
	@param promiseBulkQuery ({ number }) -> Promise<T>

	@return Aggregator<T>
]=]
function Aggregator.new(debugName: string, promiseBulkQuery)
	assert(type(debugName) == "string", "Bad debugName")

	local self = setmetatable(BaseObject.new(), Aggregator)

	self._debugName = debugName
	self._promiseBatchQuery = assert(promiseBulkQuery, "No promiseBulkQuery")

	self._promisesLruCache = LRUCache.new(2000)

	self._maxBatchSize = 200
	self._unsentCount = 0
	self._unsentPromises = {}

	return self
end

--[=[
	Sets the max batch size
	@param maxBatchSize number
]=]
function Aggregator:SetMaxBatchSize(maxBatchSize: number)
	assert(type(maxBatchSize) == "number", "Bad maxBatchSize")
	assert(self._unsentCount == 0, "Cannot set while unsent values exist")

	self._maxBatchSize = maxBatchSize
end

--[=[
	@param id number
	@return Promise<T>
]=]
function Aggregator:Promise(id: number)
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
function Aggregator:Observe(id: number)
	assert(type(id) == "number", "Bad id")

	return Rx.fromPromise(self:Promise(id))
end

function Aggregator:_sendBatchedPromises(promiseMap)
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

	self._maid:GivePromise(self._promiseBatchQuery(idList))
		:Then(function(result)
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
			promise:Reject(string.format("[Aggregator] %s failed to get result for id %d", self._debugName, id))
		end
		end, function(err, ...)
		local text = string.format("[Aggregator] %s failed to get bulk result - %q", self._debugName, tostring(err))

			for _, item in unresolvedMap do
				item:Reject(text, ...)
			end
		end)
end

function Aggregator:_resetQueue()
	local promiseMap = self._unsentPromises

	self._maid._queue = nil
	self._unsentCount = 0
	self._unsentPromises = {}

	return promiseMap
end

function Aggregator:_queueBatchRequests()
	if self._unsentCount >= self._maxBatchSize then
		self:_sendBatchedPromises(self:_resetQueue())
		return
	end

	if self._maid._queue then
		return
	end

	self._maid._queue = task.delay(0.1, function()
		task.spawn(function()
			self:_sendBatchedPromises(self:_resetQueue())
		end)
	end)
end

return Aggregator