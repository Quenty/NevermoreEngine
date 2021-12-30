--[=[
	Warps the WaitForChild API with a promise
	@class promiseChild
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

--[=[
	Wraps the :WaitForChild API with a promise

	@function promiseChild
	@param parent Instance
	@param name string
	@param timeOut number?
	@return Promise<Instance>
	@within promiseChild
]=]
return function(parent, name, timeOut)
	local result = parent:FindFirstChild(name)
	if result then
		return Promise.resolved(result)
	end

	return Promise.spawn(function(resolve, reject)
		local child = parent:WaitForChild(name, timeOut)

		if child then
			resolve(child)
		else
			reject("Timed out")
		end
	end)
end