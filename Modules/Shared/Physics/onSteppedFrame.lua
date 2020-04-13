--- Executes code at a specific point in Roblox's engine
-- @module onSteppedFrame

local RunService = game:GetService("RunService")

return function(_function)
	assert(type(_function) == "function")

	local conn
	conn = RunService.Stepped:Connect(function()
		conn:Disconnect()
		_function()
	end)

	return conn
end