--!strict
--[=[
	Collects what an observable emits into a table to assert on with `expect`.

	```lua
	local versions = RxTestUtils.collectList(controller.maid, attributeValue:Observe())

	attributeValue.Value = "2.0.0"

	expect(versions).toEqual({ "1.0.0", "2.0.0" })
	```

	@class RxTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")

local RxTestUtils = {}

--[=[
	Collects every value emitted, in order, until the maid cleans up.

	@param maid Maid
	@param observable Observable<T> -- Only the first value of each emission is recorded
	@return { T }
]=]
function RxTestUtils.collectList<T>(maid: Maid.Maid, observable: Observable.Observable<(T, ...any)>): { T }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(Observable.isObservable(observable), "Bad observable")

	local values: { T } = {}
	local count = 0

	maid:GiveTask(observable:Subscribe(function(value: T)
		count += 1
		values[count] = value
	end))

	return values
end

--[=[
	Collects every value of each emission as a list, until the maid cleans up.

	@param maid Maid
	@param observable Observable<...any>
	@return { { any } }
]=]
function RxTestUtils.collectListTuples(maid: Maid.Maid, observable: Observable.Observable<...any>): { { any } }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(Observable.isObservable(observable), "Bad observable")

	local tuples: { { any } } = {}

	maid:GiveTask(observable:Subscribe(function(...)
		table.insert(tuples, { ... })
	end))

	return tuples
end

--[=[
	Returns the values emitted synchronously on subscribe, then unsubscribes.

	@param observable Observable<T> -- Only the first value of each emission is recorded
	@return { T }
]=]
function RxTestUtils.collectSynchronousList<T>(observable: Observable.Observable<(T, ...any)>): { T }
	assert(Observable.isObservable(observable), "Bad observable")

	local values: { T } = {}
	local count = 0

	local subscription = observable:Subscribe(function(value: T)
		count += 1
		values[count] = value
	end)
	subscription:Destroy()

	return values
end

--[=[
	Collects the set of non-nil values emitted, until the maid cleans up.

	@param maid Maid
	@param observable Observable<T> -- Only the first value of each emission is recorded
	@return { [T]: true }
]=]
function RxTestUtils.collectSet<T>(maid: Maid.Maid, observable: Observable.Observable<(T, ...any)>): { [T]: true }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(Observable.isObservable(observable), "Bad observable")

	local set: { [T]: true } = {}

	maid:GiveTask(observable:Subscribe(function(value: T)
		if value ~= nil then
			set[value] = true
		end
	end))

	return set
end

return RxTestUtils
