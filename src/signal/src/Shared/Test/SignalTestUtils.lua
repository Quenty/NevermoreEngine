--!strict
--[=[
	Records what a signal fires so a test can assert on it with `expect`. Mirrors [RxTestUtils] for
	signals. Takes a [Signal], an `RBXScriptSignal`, or anything else with a `Connect` method, such as an
	[RxSignal]. A typed RxSignal needs `:: any` at the call site, since its type cannot be named here.

	```lua
	local showingComplete = SignalTestUtils.countFires(controller.maid, transitionModel.ShowingComplete)

	transitionModel:Show()

	expect(showingComplete()).toBe(1)
	```

	@class SignalTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Signal = require("Signal")

local SignalTestUtils = {}

-- Anything with a Connect method, so an RxSignal works too. This package cannot depend on RxSignal,
-- which already depends on it through Rx.
local function isSignalLike(value: any): boolean
	return Signal.isSignal(value)
		or typeof(value) == "RBXScriptSignal"
		or (type(value) == "table" and type(value.Connect) == "function")
end

--[=[
	Returns a function that reports how many times the signal has fired. The connection is given to
	the maid.

	@param maid Maid
	@param signal Signal<...any> | RBXScriptSignal
	@return () -> number
]=]
function SignalTestUtils.countFires(maid: Maid.Maid, signal: Signal.Signal<...any> | RBXScriptSignal): () -> number
	assert(Maid.isMaid(maid), "Bad maid")
	assert(isSignalLike(signal), "Bad signal")

	local count = 0

	maid:GiveTask((signal :: any):Connect(function()
		count += 1
	end))

	return function()
		return count
	end
end

--[=[
	Returns a list of the first argument of every fire, in order. The connection is given to the maid.
	A fire with no argument leaves a hole, so count those with [SignalTestUtils.countFires].

	@param maid Maid
	@param signal Signal<(T, ...any)> | RBXScriptSignal
	@return { T }
]=]
function SignalTestUtils.collectFireList<T>(maid: Maid.Maid, signal: Signal.Signal<(T, ...any)> | RBXScriptSignal): { T }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(isSignalLike(signal), "Bad signal")

	local values: { T } = {}
	local count = 0

	maid:GiveTask((signal :: any):Connect(function(value: T)
		count += 1
		values[count] = value
	end))

	return values
end

--[=[
	Returns a list with one entry per fire, each a list of every argument that fire carried, for
	signals that fire with more than one argument. The connection is given to the maid.

	```lua
	local purchases = SignalTestUtils.collectFireListTuples(controller.maid, service.GamePassPurchased)

	-- ...

	expect(purchases).toEqual({ { player, GAME_PASS_ID } })
	```

	@param maid Maid
	@param signal Signal<...any> | RBXScriptSignal
	@return { { any } }
]=]
function SignalTestUtils.collectFireListTuples(
	maid: Maid.Maid,
	signal: Signal.Signal<...any> | RBXScriptSignal
): { { any } }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(isSignalLike(signal), "Bad signal")

	local tuples: { { any } } = {}

	maid:GiveTask((signal :: any):Connect(function(...)
		table.insert(tuples, { ... })
	end))

	return tuples
end

return SignalTestUtils
