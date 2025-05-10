--!strict
--[=[
	Utility function to promise a bound class on an object
	@class promiseBoundClass
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local CancelToken = require("CancelToken")
local Promise = require("Promise")

--[=[
	Returns a promise that resolves when the class is bound to the instance.
	@param binder Binder<T>
	@param inst Instance
	@param cancelToken CancelToken
	@return Promise<T>
	@function promiseBoundClass
	@within promiseBoundClass
]=]
return function<T>(binder: Binder.Binder<T>, inst: Instance, cancelToken: CancelToken.CancelToken?): Promise.Promise<T>
	assert(Binder.isBinder(binder), "'binder' must be table")
	assert(typeof(inst) == "Instance", "'inst' must be instance")

	return binder:Promise(inst, cancelToken)
end
