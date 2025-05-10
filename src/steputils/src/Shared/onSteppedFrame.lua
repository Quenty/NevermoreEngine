--!strict
--[=[
	Executes code at a specific point in Roblox's engine
	@class onSteppedFrame
]=]

local RunService = game:GetService("RunService")

--[=[
	Executes code at a specific point in Roblox's engine.
	@function onSteppedFrame
	@param func function
	@return RBXScriptConnection
	@within onSteppedFrame
]=]
return function(func: () -> ())
	assert(type(func) == "function", "Bad func")

	return RunService.Stepped:Once(func)
end
