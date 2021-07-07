--- Promises a property value
-- @module promisePropertyValue

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

-- NOTE: To use properly please make sure to reject the promise for proper GC if the object requiring
-- this value is GCed.
return function(instance, propertyName)
	assert(typeof(instance) == "Instance")
	assert(type(propertyName) == "string")

	local result = instance[propertyName]
	if result then
		return Promise.resolved(result)
	end

	local promise = Promise.new()

	local conn
	promise:Finally(function()
		if conn then
			conn:Disconnect()
		end
	end)

	conn = instance:GetPropertyChangedSignal(propertyName):Connect(function()
		if instance[propertyName] then
			promise:Resolve(instance[propertyName])
		end
	end)

	return promise
end