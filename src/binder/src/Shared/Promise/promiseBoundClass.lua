--[=[
	Utility function to promise a bound class on an object
	@class promiseBoundClass
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Maid = require("Maid")

--[=[
Returns a promise that resolves when the class is bound to the instance.
@param binder Binder<T>
@param inst Instance
@param cancelToken CancelToken
@return Promise<T>
@function promiseBoundClass
@within promiseBoundClass
]=]
return function(binder, inst, cancelToken)
	assert(type(binder) == "table", "'binder' must be table")
	assert(typeof(inst) == "Instance", "'inst' must be instance")

	local class = binder:Get(inst)
	if class then
		return Promise.resolved(class)
	end

	local maid = Maid.new()
	local promise = Promise.new()

	if cancelToken then
		cancelToken:ErrorIfCancelled()
		maid:GivePromise(cancelToken.PromiseCancelled):Then(function()
			promise:Reject()
		end)
	end

	maid:GiveTask(binder:ObserveInstance(inst, function(classAdded)
		if classAdded then
			promise:Resolve(classAdded)
		end
	end))

	task.delay(5, function()
		if promise:IsPending() then
			warn(("[promiseBoundClass] - Infinite yield possible on %q for binder %q\n")
				:format(inst:GetFullName(), binder:GetTag()))
		end
	end)

	promise:Finally(function()
		maid:Destroy()
	end)

	return promise
end