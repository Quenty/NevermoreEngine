--[=[
	@class RateAggregator
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Queue = require("Queue")
local Promise = require("Promise")
local TupleLookup = require("TupleLookup")
local LRUCache = require("LRUCache")

local RateAggregator = setmetatable({}, BaseObject)
RateAggregator.ClassName = "RateAggregator"
RateAggregator.__index = RateAggregator

function RateAggregator.new(promiseQuery)
	local self = setmetatable(BaseObject.new(), RateAggregator)

	self._promiseQuery = promiseQuery

	-- Configuration
	self._maxRequestsPerSecond = 50
	self._minWaitTime = 1/60

	-- State tracking
	self._bankedWaitTime = 0
	self._lastQueryTime = 0
	self._queueRunning = false

	self._queue = Queue.new()
	self._tupleLookup = TupleLookup.new()
	self._promisesLruCache = LRUCache.new(2000)

	return self
end

--[=[
	Observes the aggregated data

	@param ... any
	@return Observable<T>
]=]
function RateAggregator:Promise(...)
	local promise = self._maid:GivePromise(Promise.new())

	local tuple = self._tupleLookup:ToTuple(...)
	local found = self._promisesLruCache:get(tuple)
	if found then
		return found
	end

	self._queue:PushRight({
		tuple = tuple;
		promise = promise;
	})

	self._promisesLruCache:set(tuple, promise)

	self:_startQueue()

	return promise
end

function RateAggregator:_startQueue()
	if self._queueRunning then
		return
	end

	self._queueRunning = true

	self._maid._processing = task.spawn(function()
		local timeSinceLastQuery = os.clock() - self._lastQueryTime
		if timeSinceLastQuery < 1/self._maxRequestsPerSecond then
			-- eww
			task.wait(1/self._maxRequestsPerSecond)
		end

		while not self._queue:IsEmpty() do
			local data = self._queue:PopLeft()
			self._lastQueryTime = os.clock()

			task.spawn(function()
				data.promise:Resolve(self._promiseQuery(data.tuple:Unpack()))
			end)

			local thisStepWaitTime = 1/self._maxRequestsPerSecond
			local requiredWaitTime = thisStepWaitTime - self._bankedWaitTime

			if requiredWaitTime < self._minWaitTime then
				self._bankedWaitTime -= thisStepWaitTime
			else
				local realWaitTime = math.max(self._minWaitTime, requiredWaitTime)
				local timeWaited = task.wait(realWaitTime)
				local extraWaitTime = timeWaited - requiredWaitTime
				if extraWaitTime > 0 then
					self._bankedWaitTime += extraWaitTime
				end
			end
		end

		self._bankedWaitTime = 0
		self._queueRunning = false
		self._maid._processing = nil
	end)
end

return RateAggregator