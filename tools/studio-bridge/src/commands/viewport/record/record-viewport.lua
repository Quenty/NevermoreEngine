--!strict
--[=[
	@class RecordViewportAction
]=]

local require = require(script.Parent.loader).load(script)

local ActionReply = require("ActionReply")
local FrameRecorder = require("FrameRecorder")
local ViewportCapture = require("ViewportCapture")

local MIN_FINAL_WAIT_SEC = 0.2
local MAX_FINAL_WAIT_SEC = 1

local RecordViewportAction = {}

type SendMessage = (message: { [string]: any }) -> ()

export type Services = {
	runService: any,
	captureService: any,
	assetService: any,
	encodingService: any,
	camera: any,
}

type Capture = {
	t: number,
	frame: number,
	requestedAt: number,
	contentId: string?,
}

local router: any = nil
local png: any = nil
local isTornDown = false

function RecordViewportAction.register(newRouter: any, sendMessage: SendMessage?)
	isTornDown = false
	router = newRouter
	png = newRouter._vendorPng

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

			task.spawn(function()
				local result = ActionReply.call(function()
					return RecordViewportAction._recordAsync(payload)
				end)
				if not isTornDown then
					sendMessage(ActionReply.build(sessionId, requestId, "recordViewportResult", result))
				end
			end)

			return nil
		end
	)
end

function RecordViewportAction.teardown()
	isTornDown = true
end

function RecordViewportAction._recordAsync(payload: { [string]: any }, services: Services?): { [string]: any }
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
		return ActionReply.failure("CAPTURE_FAILED", `This session can't capture the viewport: {servicesOrErr}`)
	end
	local resolved: Services = servicesOrErr

	if not resolved.runService:IsClient() then
		return ActionReply.failure(
			"CAPABILITY_NOT_SUPPORTED",
			"A playtest server renders nothing, so there is nothing to record. Run the command without --context to record Edit."
		)
	end
	local readError = ViewportCapture.checkCanRead(resolved.runService)
	if readError then
		return ActionReply.failure("CAPABILITY_NOT_SUPPORTED", readError)
	end

	local region = if type(payload.region) == "table" then payload.region else nil
	local scale = if type(payload.scale) == "number" then payload.scale else nil

	if region and resolved.camera then
		local regionError = ViewportCapture.checkRegion(region, resolved.camera.ViewportSize)
		if regionError then
			return ActionReply.failure("INVALID_REGION", regionError)
		end
	end

	local trigger, compileError = FrameRecorder.compileTrigger(router, payload.trigger)
	if compileError then
		return ActionReply.failure(
			"SCRIPT_LOAD_ERROR",
			`The --trigger code doesn't compile: {compileError}. Fix it, then run the command again.`
		)
	end

	local captures: { Capture } = {}
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
				error(
					`Studio couldn't capture a frame: {err}. Make sure the Studio window is visible, then run the command again.`,
					0
				)
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
