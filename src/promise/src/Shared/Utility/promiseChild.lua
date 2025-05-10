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
return function(parent: Instance, name: string, timeOut: number?): Promise.Promise<Instance>
	local result = parent:FindFirstChild(name)
	if result then
		return Promise.resolved(result)
	end

	return Promise.spawn(function(resolve, reject)
		local child: Instance?
		if timeOut then
			child = parent:WaitForChild(name, timeOut)
		else
			child = parent:WaitForChild(name)
		end

		if child then
			resolve(child)
		else
			reject("Timed out")
		end
	end)
end
