--- Promises a property value
-- @module promisePropertyValue

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

-- NOTE: To use properly please make sure to reject the promise for proper GC if the object requiring
-- this value is GCed.
return function(value, propertyName)
	local result = value[propertyName]
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

	conn = value:GetPropertyChangedSignal(propertyName):Connect(function()
		if value[propertyName] then
			promise:Resolve(value[propertyName])
		end
	end)

	return promise
end