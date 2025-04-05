--!strict
--[=[
	Utility function to promise a bound class on an object
	@class promiseBoundClass
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local _Promise = require("Promise")
local _CancelToken = require("CancelToken")

--[=[
	Returns a promise that resolves when the class is bound to the instance.
	@param binder Binder<T>
	@param inst Instance
	@param cancelToken CancelToken
	@return Promise<T>
	@function promiseBoundClass
	@within promiseBoundClass
]=]
return function<T>(binder: Binder.Binder<T>, inst: Instance, cancelToken: _CancelToken.CancelToken?): _Promise.Promise<T>
	assert(Binder.isBinder(binder), "'binder' must be table")
	assert(typeof(inst) == "Instance", "'inst' must be instance")

	return binder:Promise(inst, cancelToken)
end