--- Warps the WaitForChild API with a promise
-- @module promiseChild

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

--- Wraps the :WaitForChild API with a promise
return function(parent, name, timeOut)
	local result = parent:FindFirstChild(name)
	if result then
		return Promise.resolved(result)
	end

	return Promise.new(function(resolve, reject)
		-- Cheaper to do spawn() here than fastSpawn, and we aren't going to get the
		-- resource for another tick anyway
		spawn(function()
			local child = parent:WaitForChild(name, timeOut)

			if child then
				resolve(child)
			else
				reject("Timed out")
			end
		end)
	end)
end