local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

return function(parent, childName, timeOut)
	return Promise.new(function(fulfill, reject)
		local result = parent:WaitForChild(childName, timeOut)
		if result then
			fulfill(result)
		else
			reject("timed out")
		end
	end)
end