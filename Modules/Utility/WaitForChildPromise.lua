local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local Promise = require("Promise")

return function(parent, childName, timeOut)
	return Promise.new(function(fulfill, reject)
		local result = parent:WaitForChild(childName, timeOut)
		if result then
			fulfill(result)
		else
			reject("Timed out")
		end
	end)
end