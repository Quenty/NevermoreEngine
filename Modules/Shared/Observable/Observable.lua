---
-- @classmod Observable
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MaidTaskUtils = require("MaidTaskUtils")

local ENABLE_STACK_TRACING = true

local Observable = {}
Observable.ClassName = "Observable"
Observable.__index = Observable

function Observable.isObservable(item)
	return type(item) == "table" and item.ClassName == "Observable"
end

-- @param onSubscribe(fire)
function Observable.new(onSubscribe)
	return setmetatable({
		_source = ENABLE_STACK_TRACING and debug.traceback() or "Stack tracing isn't enabled";
		_onSubscribe = assert(onSubscribe, "No onSubscribe");
	}, Observable)
end

--- Subscribes immediately, fireCallback may return
-- a maid to cleanup!
-- @param fireCallback(value) => cleanup
function Observable:Subscribe(fireCallback, failCallback, completeCallback)
	assert(type(fireCallback) == "function")

	-- Closures can replace an object ;)

	local state = nil
	local hasCleaned = false
	local cleanup = nil

	-- Stream can't emit any more events after completing...
	local function doCleanup()
		if hasCleaned then
			return
		end

		hasCleaned = true
		if cleanup ~= nil then
			MaidTaskUtils.doTask(cleanup)
		end
	end

	local function fail(...)
		if not state then
			state = "fail"
			doCleanup()

			if failCallback then
				failCallback(...)
			end
		elseif state == "cancelled" then
			warn("[Observable.fail] - Already cancelled")
		end
	end

	local function complete()
		if not state then
			state = "complete"
			doCleanup()

			if completeCallback then
				completeCallback()
			end
		elseif state == "cancelled" then
			warn("[Observable.complete] - Already cancelled")
		end
	end

	local function fire(...)
		if not state then
			fireCallback(...)
		elseif state == "cancelled" then
			warn("[Observable.fire] - Already cancelled")
		end
	end

	cleanup = self._onSubscribe(fire, fail, complete)
	if not (cleanup == nil or MaidTaskUtils.isValidTask(cleanup)) then
		error("Bad cleanup functin")
	end

	-- Whoops. We've already GCed
	if hasCleaned then
		if cleanup ~= nil then
			MaidTaskUtils.doTask(cleanup)
		end
	end

	return doCleanup
end

function Observable:Pipe(transformers)
	assert(type(transformers) == "table")

	local current = self
	for _, transformer in pairs(transformers) do
		assert(type(transformer) == "function")
		current = transformer(current)
		assert(Observable.isObservable(current))
	end

	return current
end

return Observable