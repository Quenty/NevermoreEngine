--!strict
--[=[
	Utility functions primarily used to bind animations into update loops of the Roblox engine.
	@class StepUtils
]=]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local StepUtils = {}

--[=[
	Binds the given update function to [RunService.RenderStepped].

	```lua
	local spring = Spring.new(0)
	local maid = Maid.new()

	local startAnimation, maid._stopAnimation = StepUtils.bindToRenderStep(function()
		local animating, position = SpringUtils.animating(spring)

		print(position)

		return animating
	end)

	spring.t = 1
	startAnimation()
	```

	:::tip
	Be sure to call the disconnect function when cleaning up, otherwise you may memory leak.
	:::

	@param update () -> boolean -- should return true while it needs to update
	@return (...) -> () -- Connect function
	@return () -> () -- Disconnect function
]=]
function StepUtils.bindToRenderStep(update: () -> boolean): () -> ()
	return StepUtils.bindToSignal(RunService.RenderStepped, update)
end

--[=[
	Yields until the frame deferral is done
]=]
function StepUtils.deferWait(): ()
	local current = coroutine.running()
	task.defer(task.spawn, current)
	coroutine.yield()
end

--[=[
	Binds the given update function to [RunService.Stepped]. See [StepUtils.bindToRenderStep] for details.


	:::tip
	Be sure to call the disconnect function when cleaning up, otherwise you may memory leak.
	:::

	@param update () -> boolean -- should return true while it needs to update
	@return (...) -> () -- Connect function
	@return () -> () -- Disconnect function
]=]
function StepUtils.bindToStepped(update: () -> boolean): () -> ()
	return StepUtils.bindToSignal(RunService.Stepped, update)
end

--[=[
	Binds an update event to a signal until the update function stops returning a truthy
	value.

	@param signal Signal | RBXScriptSignal
	@param update () -> boolean -- should return true while it needs to update
	@return (...) -> () -- Connect function
	@return () -> () -- Disconnect function
]=]
function StepUtils.bindToSignal(signal: RBXScriptSignal, update: () -> boolean): (() -> (), () -> ())
	if typeof(signal) ~= "RBXScriptSignal" then
		error("signal must be of type RBXScriptSignal")
	end
	if type(update) ~= "function" then
		error(string.format("update must be of type function, got %q", type(update)))
	end

	local conn: RBXScriptConnection? = nil
	local function disconnect()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local function connect(...)
		-- Ignore if we have an existing connection
		if conn and conn.Connected then
			return
		end

		-- Check to see if we even need to bind an update
		if not update(...) then
			return
		end

		-- Avoid reentrance, if update() triggers another connection, we'll already be connected.
		if conn and conn.Connected then
			return
		end

		-- Usually contains just the self arg!
		local args = { ... }

		-- Bind to render stepped
		conn = signal:Connect(function()
			if not update(unpack(args)) then
				disconnect()
			end
		end)
	end

	return connect, disconnect
end

--[=[
	Calls the function once at the given priority level, unless the cancel callback is
	invoked.

	@param priority number
	@param func function -- Function to call
	@return function -- Call this function to cancel call
]=]
function StepUtils.onceAtRenderPriority(priority: number, func: () -> ()): () -> ()
	assert(type(priority) == "number", "Bad priority")
	assert(type(func) == "function", "Bad func")

	local key = string.format("StepUtils.onceAtPriority_%s", HttpService:GenerateGUID(false))

	local function cleanup()
		RunService:UnbindFromRenderStep(key)
	end

	RunService:BindToRenderStep(key, priority, function()
		cleanup()
		func()
	end)

	return cleanup
end

--[=[
	Invokes the function once at stepped, unless the cancel callback is called.

	```lua
	-- Sometimes you need to defer the execution of code to make physics happy
	maid:GiveTask(StepUtils.onceAtStepped(function()
		part.CFrame = CFrame.new(0, 0, )
	end))
	```

	:::tip
	use `RunService.Stepped:Once()` instead
	:::

	@deprecated 3.5.2
	@param func function -- Function to call
	@return function -- Call this function to cancel call
]=]
function StepUtils.onceAtStepped(func: () -> ()): () -> ()
	local conn = RunService.Stepped:Once(func)
	return function()
		conn:Disconnect()
	end
end

--[=[
	Invokes the function once at renderstepped, unless the cancel callback is called.

	:::tip
	use `RunService.RenderStepped:Once()` instead
	:::

	@deprecated 3.5.2
	@param func function -- Function to call
	@return function -- Call this function to cancel call
]=]
function StepUtils.onceAtRenderStepped(func: () -> ()): () -> ()
	local conn = RunService.RenderStepped:Once(func)
	return function()
		conn:Disconnect()
	end
end

--[=[
	Invokes the function once at the given event, unless the cancel callback is called.

	@deprecated 3.5.2
	@param event Signal | RBXScriptSignal
	@param func function -- Function to call
	@return function -- Call this function to cancel call
]=]
function StepUtils.onceAtEvent(event: RBXScriptSignal, func: () -> ()): () -> ()
	assert(type(func) == "function", "Bad func")

	local conn: RBXScriptConnection?
	local function cleanup()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end

	conn = event:Connect(function(...)
		cleanup()
		func(...)
	end)

	return cleanup
end

return StepUtils
