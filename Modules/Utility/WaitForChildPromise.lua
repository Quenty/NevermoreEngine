local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Promise = LoadCustomLibrary("Promise")

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