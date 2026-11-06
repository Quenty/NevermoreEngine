--!strict
--[=[
	Library that records a window of frames, shared by the actions that watch
	something change over time (`sampleInstances`, `recordViewport`).

	- Frame 0 is the frame the trigger runs in. Without a trigger, recording
	  starts passively on the next frame.
	- `t` is the sum of frame deltas since frame 0, not wall time, so it lines
	  up with what animation code saw.
	- Binds at `Enum.RenderPriority.Last`, so values are read after that frame's
	  animation code has run. Where render stepping is not available (a
	  playtest's server), it steps on Heartbeat instead.
	- Records frame 0, then a frame each `1 / fps` seconds (every frame without
	  `fps`), through the first frame at or past `duration`, which is always
	  recorded. Stops early after `maxFrames` recorded frames.

	Pushed like an action, but registers no handlers: it puts itself on
	`router._libraries` for the actions to look up when a request arrives.

	@class FrameRecorder
]=]

local DEFAULT_MAX_FRAMES = 300
-- Frame deltas are floats, so a sample due at 0.1s may land at 0.0999999
local EPSILON = 1e-6

local FrameRecorder = {}

export type Services = {
	runService: any,
}

export type Options = {
	-- Runs in frame 0. May yield; an error stops the recording.
	trigger: (() -> ())?,
	-- Seconds to record
	duration: number,
	fps: number?,
	maxFrames: number?,
	-- Called for each frame due to be recorded. Must not yield.
	onFrame: (t: number, frame: number) -> (),
}

export type Clock = "renderStep" | "heartbeat"

export type Result = {
	-- Frames `onFrame` recorded
	recorded: number,
	-- Frames stepped through, frame 0 included
	frameCount: number,
	-- `t` of the last frame
	elapsed: number,
	-- Stopped at `maxFrames` before the duration had elapsed
	truncated: boolean,
	clock: Clock,
	-- Why the recording stopped early, when the trigger or `onFrame` threw
	error: string?,
}

local recordingCount = 0

--[=[
	Makes the library available to actions as `router._libraries["frame-recorder"]`.
]=]
function FrameRecorder.register(router: any)
	router._libraries = router._libraries or {}
	router._libraries["frame-recorder"] = FrameRecorder
end

--[=[
	Compiles a trigger's Luau source the way `execute` compiles code, through
	the router's `Compile` where the plugin has one. Returns nil without a
	source, or nil and the compile error.
]=]
function FrameRecorder.compileTrigger(router: any, source: string?): ((() -> ())?, string?)
	if type(source) ~= "string" or source == "" then
		return nil, nil
	end

	local ok, fn, compileErr
	if type(router.Compile) == "function" then
		ok, fn, compileErr = pcall(router.Compile, router, source, "=trigger")
	else
		ok, fn, compileErr = pcall(loadstring :: any, source, "=trigger")
	end

	if not ok then
		return nil, tostring(fn)
	end
	if not fn then
		return nil, compileErr or "the trigger did not compile"
	end
	return fn, nil
end

--[=[
	Records frames as described above, yielding until the recording ends.
]=]
function FrameRecorder.recordAsync(options: Options, services: Services?): Result
	local runService = if services then services.runService else game:GetService("RunService")
	local interval = if type(options.fps) == "number" and options.fps > 0 then 1 / options.fps else 0
	local maxFrames = options.maxFrames or DEFAULT_MAX_FRAMES

	local result: Result = {
		recorded = 0,
		frameCount = 0,
		elapsed = 0,
		truncated = false,
		clock = "renderStep",
		error = nil,
	}

	local callerThread = coroutine.running()
	local isWaiting = false
	local isDone = false
	local frame = -1
	local t = 0
	local nextRecordAt = 0
	local stopStepping: () -> () = function() end

	local function finish()
		if isDone then
			return
		end
		isDone = true
		stopStepping()
		if isWaiting then
			task.spawn(callerThread)
		end
	end

	local function step(deltaTime: number)
		if isDone then
			return
		end

		frame += 1
		if frame == 0 then
			if options.trigger then
				local trigger = options.trigger
				task.spawn(function()
					local ok, err = xpcall(trigger, debug.traceback)
					if not ok and not result.error then
						result.error = `Trigger failed: {err}`
					end
				end)
			end
		else
			t += deltaTime
		end
		result.frameCount = frame + 1
		result.elapsed = t

		if result.error then
			finish()
			return
		end

		local isLast = t + EPSILON >= options.duration
		if isLast or t + EPSILON >= nextRecordAt then
			local ok, err = pcall(options.onFrame, t, frame)
			if not ok then
				result.error = tostring(err)
				finish()
				return
			end

			result.recorded += 1
			if interval > 0 then
				nextRecordAt = (math.floor((t + EPSILON) / interval) + 1) * interval
			end
		end

		if isLast then
			finish()
		elseif result.recorded >= maxFrames then
			result.truncated = true
			finish()
		end
	end

	recordingCount += 1
	local renderStepName = `StudioBridgeFrameRecorder{recordingCount}`
	local bindOk = pcall(runService.BindToRenderStep, runService, renderStepName, Enum.RenderPriority.Last.Value, step)
	if bindOk then
		stopStepping = function()
			runService:UnbindFromRenderStep(renderStepName)
		end
	else
		result.clock = "heartbeat"
		local connection = runService.Heartbeat:Connect(step)
		stopStepping = function()
			connection:Disconnect()
		end
	end

	if not isDone then
		isWaiting = true
		coroutine.yield()
	end

	return result
end

return FrameRecorder
