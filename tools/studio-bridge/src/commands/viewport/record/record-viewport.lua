--!strict
--[=[
	Action that records the Studio viewport over a window of frames, optionally
	after running a trigger.

	While recording it only asks CaptureService for a capture each recorded
	frame, and remembers each request's `t` and frame: a capture holds the frame
	it was requested in, though its callback fires frames later. Pixel work
	waits until the window is over: then it reads each capture, cropped to
	`region` and scaled by `scale`, and encodes it as PNG with the plugin's
	encoder (raw RGBA without one). A capture that fails to read is skipped and
	reported, rather than failing the whole recording.

	CaptureService accepts about one request every few frames and silently
	drops the rest, never calling them back. Requests it dropped are left out,
	so the reply holds the captures it really made, at their real times. Asking
	every frame, rather than waiting for each capture to come back before asking
	for the next, gets about twice as many, since it overlaps captures in flight.

	Request: `{ type: "recordViewport", payload: { trigger?, duration, fps?, maxFrames?, region?, scale? } }`
	Response: `{ type: "recordViewportResult", payload: { frames: { { t, frame, width, height, format, data } }, skipped: { { t, frame, reason } }, requested, frameCount, elapsed, truncated, clock } }`

	@class RecordViewportAction
]=]

-- Bounds on how long to wait, after the window, for captures still in flight
local MIN_FINAL_WAIT_SEC = 0.2
local MAX_FINAL_WAIT_SEC = 1

local RecordViewportAction = {}

type SendMessage = (message: { [string]: any }) -> ()

export type Services = {
	runService: any,
	captureService: any,
	assetService: any,
	encodingService: any,
	-- Its ViewportSize is what a capture covers, for checking the region up front
	camera: any,
}

type Capture = {
	t: number,
	frame: number,
	requestedAt: number,
	contentId: string?,
}

local router: any = nil
-- The plugin hands its PNG encoder over through router._vendorPng
local png: any = nil
-- Filled in by the libraries, which may be pushed after this action
local libraries: { [string]: any } = {}
local isTornDown = false

--[=[
	Registers the `recordViewport` handler. Recording takes many frames, so it
	replies asynchronously through `sendMessage`.
]=]
function RecordViewportAction.register(newRouter: any, sendMessage: SendMessage?)
	isTornDown = false
	router = newRouter
	png = newRouter._vendorPng
	newRouter._libraries = newRouter._libraries or {}
	libraries = newRouter._libraries

	newRouter:setResponseType("recordViewport", "recordViewportResult")
	newRouter:register(
		"recordViewport",
		function(payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
			if not sendMessage then
				return {
					success = false,
					code = "CAPABILITY_NOT_SUPPORTED",
					message = "Recording requires a sendMessage callback",
				}
			end

			local ActionReply = libraries["action-reply"]
			if not ActionReply then
				return {
					success = false,
					code = "INTERNAL_ERROR",
					message = "The action-reply library is not installed",
				}
			end

			task.spawn(function()
				local result = RecordViewportAction._recordAsync(payload)
				if not isTornDown then
					sendMessage(ActionReply.build(sessionId, requestId, "recordViewportResult", result))
				end
			end)

			-- Replied through sendMessage, so the router must not reply as well
			return nil
		end
	)
end

--[=[
	Stops an in-flight recording from replying.
]=]
function RecordViewportAction.teardown()
	isTornDown = true
end

function RecordViewportAction._recordAsync(payload: { [string]: any }, services: Services?): { [string]: any }
	local ActionReply = libraries["action-reply"]
	local FrameRecorder = libraries["frame-recorder"]
	local ViewportCapture = libraries["viewport-capture"]
	if not (ActionReply and FrameRecorder and ViewportCapture) then
		return {
			success = false,
			code = "INTERNAL_ERROR",
			message = "The recording libraries are not installed",
		}
	end

	if type(payload.duration) ~= "number" then
		return ActionReply.failure("INVALID_PAYLOAD", "duration is required")
	end

	local servicesOk, servicesOrErr = pcall(function(): Services
		return services
			or {
				runService = game:GetService("RunService"),
				captureService = game:GetService("CaptureService"),
				assetService = game:GetService("AssetService"),
				encodingService = game:GetService("EncodingService"),
				camera = workspace.CurrentCamera,
			}
	end)
	if not servicesOk then
		return ActionReply.failure("CAPTURE_FAILED", `Required services not available: {servicesOrErr}`)
	end
	local resolved: Services = servicesOrErr

	if not resolved.runService:IsClient() then
		return ActionReply.failure(
			"CAPABILITY_NOT_SUPPORTED",
			"A server renders nothing to record. Record Edit or a playtest's client instead"
		)
	end

	local region = if type(payload.region) == "table" then payload.region else nil
	local scale = if type(payload.scale) == "number" then payload.scale else nil

	-- Refused before the trigger runs, rather than after the whole recording
	if region and resolved.camera then
		local regionError = ViewportCapture.checkRegion(region, resolved.camera.ViewportSize)
		if regionError then
			return ActionReply.failure("INVALID_REGION", regionError)
		end
	end

	local trigger, compileError = FrameRecorder.compileTrigger(router, payload.trigger)
	if compileError then
		return ActionReply.failure("SCRIPT_LOAD_ERROR", `Trigger did not compile: {compileError}`)
	end

	local captures: { Capture } = {}
	-- CaptureService answers in request order, so a request older than the
	-- newest answered one was dropped
	local newestAnswered = 0
	local longestWait = 0

	local recording = FrameRecorder.recordAsync({
		trigger = trigger,
		duration = payload.duration,
		fps = payload.fps,
		maxFrames = payload.maxFrames,
		onFrame = function(t: number, frame: number)
			local capture: Capture = { t = t, frame = frame, requestedAt = os.clock(), contentId = nil }
			table.insert(captures, capture)
			local index = #captures

			local ok, err = ViewportCapture.requestCapture(resolved.captureService, function(contentId: string)
				capture.contentId = contentId
				newestAnswered = math.max(newestAnswered, index)
				longestWait = math.max(longestWait, os.clock() - capture.requestedAt)
			end)
			if not ok then
				error(`CaptureService failed: {err}`, 0)
			end
		end,
	}, { runService = resolved.runService })

	if recording.error then
		return ActionReply.failure("RECORD_FAILED", recording.error)
	end

	RecordViewportAction._waitForLastCaptures(captures, function()
		return newestAnswered
	end, longestWait)

	local frames = {}
	local skipped = {}
	for _, capture in captures do
		local contentId = capture.contentId
		if not contentId or contentId == "" then
			continue
		end

		local read, _, message = ViewportCapture.readPixelsAsync(resolved.assetService, contentId, {
			region = region,
			scale = scale,
		})
		local encoded, formatOrErr = nil, message
		if read then
			encoded, formatOrErr = ViewportCapture.encodeBase64(png, resolved.encodingService, read)
		end

		if read and encoded then
			table.insert(frames, {
				t = capture.t,
				frame = capture.frame,
				width = read.width,
				height = read.height,
				format = formatOrErr,
				data = encoded,
			})
		else
			table.insert(skipped, {
				t = capture.t,
				frame = capture.frame,
				reason = formatOrErr or "unknown error",
			})
		end
	end

	return {
		frames = frames,
		skipped = skipped,
		requested = #captures,
		frameCount = recording.frameCount,
		elapsed = recording.elapsed,
		truncated = recording.truncated,
		clock = recording.clock,
	}
end

--[[
	Waits for captures still in flight after the window. Only requests newer
	than the newest answered one can still answer, since CaptureService answers
	in order and never answers the ones it dropped. Waits for those up to twice
	the longest any capture took, within bounds, since the newest request may
	itself have been dropped.
]]
function RecordViewportAction._waitForLastCaptures(
	captures: { Capture },
	getNewestAnswered: () -> number,
	longestWait: number
)
	local last = captures[#captures]
	if not last then
		return
	end

	local waitSec = math.clamp(longestWait * 2, MIN_FINAL_WAIT_SEC, MAX_FINAL_WAIT_SEC)
	local deadline = last.requestedAt + waitSec
	while getNewestAnswered() < #captures and os.clock() < deadline do
		task.wait()
	end
end

return RecordViewportAction
