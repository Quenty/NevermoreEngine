--- Executes code at a specific point in render step priority queue
-- @module onRenderStepFrame

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

return function(priority, _function)
	assert(type(priority) == "number")
	assert(type(_function) == "function")

	local key = HttpService:GenerateGUID(false) .. "_onRenderStepFrame"

	RunService:BindToRenderStep(key, priority, function()
		RunService:UnbindFromRenderStep(key)
		_function()
	end)
end