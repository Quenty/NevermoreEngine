--!strict
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
local _Observable = require("Observable")

local PromptQueue = setmetatable({}, BaseObject)
PromptQueue.ClassName = "PromptQueue"
PromptQueue.__index = PromptQueue

type PromptEntry = {
	promise: Promise.Promise<()>,
	execute: () -> (),
	cancel: (doNotAnimate: boolean?) -> (),
}

export type PromptQueue = typeof(setmetatable(
	{} :: {
		_isShowing: ValueObject.ValueObject<boolean>,
		_clearRequested: Signal.Signal<(boolean?)>,
		_queue: { PromptEntry },
		_currentProcessingEntry: PromptEntry?,
	},
	{} :: typeof({ __index = PromptQueue })
)) & BaseObject.BaseObject

--[=[
	Constructs a new prompt queue
	@return PromptQueue
]=]
function PromptQueue.new(): PromptQueue
	local self: PromptQueue = setmetatable(BaseObject.new() :: any, PromptQueue)

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
function PromptQueue.Queue(self: PromptQueue, transitionModel: TransitionModel.TransitionModel): Promise.Promise<()>
	assert(TransitionModel.isTransitionModel(transitionModel), "Bad transitionModel")

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	local isCancelling: boolean = false

	local entry: PromptEntry = {
		promise = promise,
		execute = function()
		assert(promise:IsPending(), "Not pending")

			-- stylua: ignore
			maid:GivePromise(transitionModel:PromiseShow())
				:Then(function()
					if (transitionModel :: any).PromiseSustain then
						return maid:GivePromise((transitionModel :: any):PromiseSustain())
					end

					return nil
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
		end,
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
		end,
	}

	table.insert(self._queue, entry)

	maid:GiveTask(self._clearRequested:Connect(function(doNotAnimate: boolean?)
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
function PromptQueue.HasItems(self: PromptQueue): boolean
	return #self._queue > 0
end

--[=[
	Clears the current queue

	@param doNotAnimate boolean?
]=]
function PromptQueue.Clear(self: PromptQueue, doNotAnimate: boolean?)
	self._clearRequested:Fire(doNotAnimate)
end

--[=[
	Promises the current prompt to be hidden

	@param doNotAnimate boolean?
	@return Promise
]=]
function PromptQueue.HideCurrent(self: PromptQueue, doNotAnimate: boolean?)
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
function PromptQueue.IsShowing(self: PromptQueue): boolean
	return self._isShowing.Value
end

--[=[
	Observes the current state of the PromptQueue, emitting true when showing and false if not.

	@return Observable<boolean>
]=]
function PromptQueue.ObserveIsShowing(self: PromptQueue): _Observable.Observable<boolean>
	return self._isShowing:Observe()
end

function PromptQueue._startQueueProcessing(self: PromptQueue)
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