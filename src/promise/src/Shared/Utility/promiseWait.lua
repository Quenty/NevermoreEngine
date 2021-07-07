--- Wraps the wait()/delay() API in a promise
-- @module promiseWait

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

return function(time)
	return Promise.new(function(resolve, reject)
		delay(time, function()
			resolve()
		end)
	end)
end