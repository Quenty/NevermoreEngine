--[=[
	Executes code at a specific point in render step priority queue
	@class onRenderStepFrame
]=]

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

--[=[
	Executes code at a specific point in render step priority queue.
	@function onRenderStepFrame
	@param priority number
	@return MaidTask
	@within onRenderStepFrame
]=]

return function(priority, callback)
	assert(type(priority) == "number", "Bad priority")
	assert(type(callback) == "function", "Bad callback")

	local key = HttpService:GenerateGUID(false) .. "_onRenderStepFrame"
	local unbound = false

	RunService:BindToRenderStep(key, priority, function()
		if not unbound then -- Probably not needed
			RunService:UnbindFromRenderStep(key)
			callback()
		end
	end)

	return function()
		if not unbound then
			RunService:UnbindFromRenderStep(key)
			unbound = true
		end
	end
end