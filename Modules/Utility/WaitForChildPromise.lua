local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local WaitForChildPromise = {}

function WaitForChildPromise.new(parent, childName, timeOut)
	timeOut = timeOut or 5

	return Promise.new(function(fulfill, reject)
		local result = parent:WaitForChild(childName, timeOut)
		if result then
			fulfill(result)
		else
			reject("timed out")
		end
	end)
end

return WaitForChildPromise