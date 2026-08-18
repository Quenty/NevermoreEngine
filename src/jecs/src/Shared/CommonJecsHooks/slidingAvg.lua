--!nonstrict
--[=[
	@class slidingAvg

	If you call this hook with a constantly updating number or vector,
	it will return the average of the last windowSize values.
	Optionally, pass in a boolean/condition flag to determine if you actually
	want to add it to the sliding average.
	(You can put a throttle hook in that flag argument.)

	This also returns callbacks to add values outside of calling
	this hook, like manually populating the values queue or clearing it.

	Pass fillBufferWithFirstValue to seed the window with the first sample (warm start).
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateHookAverageUtils = require("ImmediateHookAverageUtils")
local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(
		dis: any?,
		value: ImmediateHookAverageUtils.AverageableValue,
		windowSize: number,
		conditionToInclude: boolean?,
		fillBufferWithFirstValue: boolean?
	)
		assert(windowSize >= 1, "slidingAvg windowSize must be >= 1")

		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
		if not hookState.init then
			hookState.init = true
			hookState.windowSize = windowSize
			hookState.buffer = table.create(windowSize)
			hookState.head = 1
			hookState.count = 0
			hookState.sum = ImmediateHookAverageUtils.zeroSum(value)
			hookState.zeroSum = hookState.sum
			hookState.push = function(pushValue: ImmediateHookAverageUtils.AverageableValue)
				local capacity = hookState.windowSize
				local i = hookState.head
				local old = hookState.buffer[i]
				hookState.buffer[i] = pushValue
				hookState.head = (i % capacity) + 1
				if hookState.count < capacity then
					hookState.count += 1
					hookState.sum += pushValue
				else
					hookState.sum += pushValue - old
				end
			end
			hookState.clear = function()
				table.clear(hookState.buffer)
				hookState.head = 1
				hookState.count = 0
				hookState.sum = hookState.zeroSum
			end
			if fillBufferWithFirstValue then
				for _ = 1, windowSize do
					hookState.push(value)
				end
			end
		end

		if conditionToInclude ~= nil then
			if conditionToInclude == true then
				hookState.push(value)
			end
		else
			hookState.push(value)
		end

		return ImmediateHookAverageUtils.quotient(hookState.sum, hookState.count), hookState.push, hookState.clear
	end
end
