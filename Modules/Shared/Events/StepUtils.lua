--- Binds animations into step, where the animation only runs as needed
-- @module StepUtils
-- @author Quenty

local RunService = game:GetService("RunService")

local StepUtils = {}

-- update should return true while it needs to update
function StepUtils.bindToRenderStep(update)
	assert(type(update) == "function")

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

return StepUtils