--[=[
	Queue system for prompts and other UI

	@class PromptQueue
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local BaseObject = require("BaseObject")
local Promise = require("Promise")
local TransitionModel = require("TransitionModel")
local ValueObject = require("ValueObject")
local Signal = require("Signal")

local PromptQueue = setmetatable({}, BaseObject)
PromptQueue.ClassName = "PromptQueue"
PromptQueue.__index = PromptQueue

--[=[
	Constructs a new prompt queue
	@return PromptQueue
]=]
function PromptQueue.new()
	local self = setmetatable(BaseObject.new(), PromptQueue)

	self._isShowing = self._maid:Add(ValueObject.new(false, "boolean"))
	self._clearRequested = self._maid:Add(Signal.new())

	self._queue = {}
	self._currentProcessingEntry = nil

	return self
end

--[=[
	Queues a transition model to be shown

	@param transitionModel TransitionModel
]=]
function PromptQueue:Queue(transitionModel)
	assert(TransitionModel.isTransitionModel(transitionModel), "Bad transitionModel")

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	local isCancelling = false

	local entry = {
		promise = promise;
		execute = function()
			assert(promise:IsPending(), "Not pending")

			maid:GivePromise(transitionModel:PromiseShow())
				:Then(function()
					if transitionModel.PromiseSustain then
						return maid:GivePromise(transitionModel:PromiseSustain())
					end
				end)
				:Then(function()
					return maid:GivePromise(transitionModel:PromiseHide())
				end)
				:Then(function()
					promise:Resolve()
				end)
				:Catch(function(...)
					if promise:IsPending() then
						return
					end

					if isCancelling then
						return
					end

					warn(string.format("[PromptQueue] - Failed to execute due to %q", tostring(... or nil)))
					return  Promise.rejected(...)
				end)
		end;
		cancel = function(doNotAnimate)
			assert(promise:IsPending(), "Not pending")
			if isCancelling then
				return
			end

			isCancelling = true

			maid:GivePromise(transitionModel:PromiseHide(doNotAnimate))
				:Then(function()
					promise:Resolve()
				end)
				:Catch(function(...)
					promise:Reject(...)

					if select("#", ...) > 0 then
						warn(string.format("[PromptQueue] - Failed to cancel due to %q", tostring(... or nil)))
					end

					return Promise.rejected(...)
				end)
		end;
	}

	table.insert(self._queue, entry)


	maid:GiveTask(self._clearRequested:Connect(function(doNotAnimate)
		entry.cancel(doNotAnimate)
	end))

	promise:Finally(function()
		self._maid[maid] = nil
	end)
	maid:GiveTask(function()
		if self._currentProcessingEntry == entry then
			self._currentProcessingEntry = nil
		end

		local index = table.find(self._queue, entry)
		if index then
			table.remove(self._queue, index)
		end

		self._maid[maid] = nil
	end)

	self._maid[maid] = maid

	self:_startQueueProcessing()

	return promise
end

--[=[
	Returns if the queue has any items

	@return boolean
]=]
function PromptQueue:HasItems()
	return #self._queue > 0
end

--[=[
	Clears the current queue

	@param doNotAnimate boolean?
]=]
function PromptQueue:Clear(doNotAnimate)
	self._clearRequested:Fire(doNotAnimate)
end

--[=[
	Promises the current prompt to be hidden

	@param doNotAnimate boolean?
	@return Promise
]=]
function PromptQueue:HideCurrent(doNotAnimate)
	if self._currentProcessingEntry then
		local promise = self._currentProcessingEntry.promise

		self._currentProcessingEntry.cancel(doNotAnimate)

	 	return promise
	else
		return Promise.resolved()
	end
end

--[=[
	Returns whether or not the PromptQueue is currently showing its contents.
	
	@return boolean
]=]
function PromptQueue:IsShowing()
	return self._isShowing.Value
end

--[=[
	Observes the current state of the PromptQueue, emitting true when showing and false if not.

	@return Observable<boolean>
]=]
function PromptQueue:ObserveIsShowing()
	return self._isShowing:Observe()
end

function PromptQueue:_startQueueProcessing()
	if self._maid._processing then
		return
	end

	self._maid._processing = task.spawn(function()
		self._isShowing.Value = true

		local current = table.remove(self._queue, 1)
		while current do
			self._currentProcessingEntry = current

			current.execute()
			current.promise:Yield()

			if self._currentProcessingEntry == current then
				self._currentProcessingEntry = nil
			end

			-- Otherwise  we have an issue where we process stuff that should have been already removed...?
			task.wait(0.05)

			current = table.remove(self._queue, 1)
		end

		self._isShowing.Value = false
		self._maid._processing = nil
	end)
end

return PromptQueue