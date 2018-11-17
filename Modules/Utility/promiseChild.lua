--- Warps the WaitForChild API with a promise
-- @module promiseChild

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

--- Wraps the :WaitForChild API with a promise
return function(parent, name, timeOut)
	return Promise.new(function(resolve, reject)
		local child = parent:WaitForChild(name, timeOut)
		if child then
			resolve(child)
		else
			reject("Timed out")
		end
	end)
end