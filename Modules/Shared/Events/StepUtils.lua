--- Binds animations into step, where the animation only runs as needed
-- @module StepUtils
-- @author Quenty

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local StepUtils = {}

-- update should return true while it needs to update
function StepUtils.bindToRenderStep(update)
	if type(update) ~= "function" then
		error(("update must be of type function, got %q"):format(type(update)))
	end

	local conn = nil
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
		local args = {...}

		-- Bind to render stepped
		conn = RunService.RenderStepped:Connect(function()
			if not update(unpack(args)) then
				disconnect()
			end
		end)
	end

	return connect, disconnect
end

function StepUtils.onceAtRenderPriority(priority, func)
	assert(type(priority) == "number")
	assert(type(func) == "function")

	local key = ("StepUtils.onceAtPriority_%s"):format(HttpService:GenerateGUID(false))

	local function cleanup()
		RunService:UnbindFromRenderStep(key)
	end

	RunService:BindToRenderStep(key, priority, function()
		cleanup()
		func()
	end)

	return cleanup
end

return StepUtils