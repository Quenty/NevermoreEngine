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
function Aggregator.new(debugName, promiseBulkQuery)
	assert(type(debugName) == "string", "Bad debugName")

	local self = setmetatable(BaseObject.new(), Aggregator)

	self._debugName = debugName
	self._promiseBulkQuery = assert(promiseBulkQuery, "No promiseBulkQuery")

	-- TODO: LRU cache this? Limit to 1k or something?
	self._promisesLruCache = LRUCache.new(2000)

	self._maxPerRequest = 200
	self._unsentCount = 0
	self._unsentPromises = {}

	return self
end

--[=[
	@param id number
	@return Promise<T>
]=]
function Aggregator:Promise(id)
	assert(type(id) == "number", "Bad id")

	local found = self._promisesLruCache:get(id)
	if found then
		return found
	end

	local promise = Promise.new()

	self._unsentPromises[id] = promise
	self._unsentCount = self._unsentCount + 1
	self._promisesLruCache:set(id, promise)

	self:_queueAggregatedPromises()

	return promise
end

--[=[
	Observes the aggregated data

	@param id number
	@return Observable<T>
]=]
function Aggregator:Observe(id)
	assert(type(id) == "number", "Bad id")

	return Rx.fromPromise(self:Promise(id))
end

function Aggregator:_sendAggregatedPromises(promiseMap)
	assert(promiseMap, "No promiseMap")

	local idList = {}
	local unresolvedMap = {}
	for id, promise in pairs(promiseMap) do
		table.insert(idList, id)
		unresolvedMap[id] = promise
	end

	if #idList == 0 then
		return
	end

	assert(#idList <= self._maxPerRequest, "Too many idList sent")

	self._maid:GivePromise(self._promiseBulkQuery(idList))
		:Then(function(result)
			assert(type(result) == "table", "Bad result")

			for _, data in pairs(result) do
				assert(type(data.Id) == "number", "Bad result[?].Id")

				if unresolvedMap[data.Id] then
					unresolvedMap[data.Id]:Resolve(data)
					unresolvedMap[data.Id] = nil
				end
			end

			-- Reject other ones
			for id, promise in pairs(unresolvedMap) do
				promise:Reject(string.format("Aggregated %s failed to get result for id %d", self._debugName, id))
			end
		end, function(...)
			for _, item in pairs(unresolvedMap) do
				item:Reject(...)
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

function Aggregator:_queueAggregatedPromises()
	if self._unsentCount >= self._maxPerRequest then
		self:_sendAggregatedPromises(self:_resetQueue())
		return
	end

	if self._maid._queue then
		return
	end

	self._maid._queue = task.delay(0.1, function()
		task.spawn(function()
			self:_sendAggregatedPromises(self:_resetQueue())
		end)
	end)
end

return Aggregator