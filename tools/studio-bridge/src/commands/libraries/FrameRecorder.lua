--!strict
--[=[
	@class FrameRecorder
]=]

local DEFAULT_MAX_FRAMES = 300
local FRAME_TIME_TOLERANCE = 1e-6

local FrameRecorder = {}

FrameRecorder.FIRST_FRAME_TIMEOUT_SECONDS = 5

export type Services = {
	runService: any,
}

export type Options = {
	trigger: (() -> ())?,
	onStart: (() -> ())?,
	duration: number,
	fps: number?,
	maxFrames: number?,
	onFrame: (t: number, frame: number) -> boolean?,
}

export type Clock = "renderStep" | "heartbeat"

export type Result = {
	recorded: number,
	frameCount: number,
	elapsed: number,
	truncated: boolean,
	clock: Clock,
	error: string?,
}

local recordingCount = 0

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
			if options.onStart then
				local ok, err = pcall(options.onStart)
				if not ok then
					result.error = tostring(err)
					finish()
					return
				end
			end
			if options.trigger then
				local trigger = options.trigger
				task.spawn(function()
					local ok, err = xpcall(trigger, debug.traceback)
					if not ok and not result.error then
						result.error = `The --trigger code threw an error: {err}`
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

		local isLast = t + FRAME_TIME_TOLERANCE >= options.duration
		if isLast or t + FRAME_TIME_TOLERANCE >= nextRecordAt then
			local ok, errOrStop = pcall(options.onFrame, t, frame)
			if not ok then
				result.error = tostring(errOrStop)
				finish()
				return
			end
			if errOrStop == true then
				finish()
				return
			end

			result.recorded += 1
			if interval > 0 then
				nextRecordAt = (math.floor((t + FRAME_TIME_TOLERANCE) / interval) + 1) * interval
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
	local bindOk = FrameRecorder._hasRenderStep(runService)
		and pcall(runService.BindToRenderStep, runService, renderStepName, Enum.RenderPriority.Last.Value, step)
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

	task.delay(FrameRecorder.FIRST_FRAME_TIMEOUT_SECONDS, function()
		if frame < 0 and not isDone then
			result.error =
				`Studio didn't step a frame within {FrameRecorder.FIRST_FRAME_TIMEOUT_SECONDS}s, so nothing was recorded. Make sure Studio isn't paused or minimized, then run the command again.`
			finish()
		end
	end)

	if not isDone then
		isWaiting = true
		coroutine.yield()
	end

	return result
end

function FrameRecorder._hasRenderStep(runService: any): boolean
	return type(runService.IsClient) ~= "function" or runService:IsClient()
end

return FrameRecorder
