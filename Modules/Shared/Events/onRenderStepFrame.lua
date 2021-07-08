--- Executes code at a specific point in render step priority queue
-- @module onRenderStepFrame

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

return function(priority, callback)
	assert(type(priority) == "number")
	assert(type(callback) == "function")

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