--- Utility function to promise a bound class on an object
-- @function promiseBoundClass

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Maid = require("Maid")

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

	delay(5, function()
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