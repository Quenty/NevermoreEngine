--!optimize 2
--[=[
	Action that captures the Studio viewport and answers with it as base64.

	Request: `{ type: "captureScreenshot", payload: { format?: "png", region?: { x, y, w, h }, scale? } }`
	Response: `{ type: "screenshotResult", payload: { data, format, width, height } }`

	@class CaptureScreenshotAction
]=]

local require = require(script.Parent.loader).load(script)

local ActionReply = require("ActionReply")
local ViewportCapture = require("ViewportCapture")

local CaptureScreenshotAction = {}

type SendMessage = (message: { [string]: any }) -> ()

export type Services = {
	runService: any,
	captureService: any,
	assetService: any,
	encodingService: any,
}

-- The plugin hands its PNG encoder over through router._vendorPng
local png: any = nil
local isTornDown = false

--[=[
	Registers the `captureScreenshot` handler. Capturing replies asynchronously,
	so it needs `sendMessage`.
]=]
function CaptureScreenshotAction.register(router: any, sendMessage: SendMessage?)
	isTornDown = false
	png = router._vendorPng

	router:setResponseType("captureScreenshot", "screenshotResult")
	router:register(
		"captureScreenshot",
		function(payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
			if not sendMessage then
				return {
					code = "CAPABILITY_NOT_SUPPORTED",
					message = "Screenshot capture requires a sendMessage callback",
				}
			end

			-- Lune has no task library, so fall back to running inline there
			local spawnOk = pcall(function()
				task.spawn(CaptureScreenshotAction._captureAsync, sendMessage, requestId, sessionId, nil, payload)
			end)
			if not spawnOk then
				CaptureScreenshotAction._captureAsync(sendMessage, requestId, sessionId, nil, payload)
			end

			-- Replied through sendMessage, so the router must not reply as well
			return nil
		end
	)
end

--[=[
	Stops an in-flight capture from replying.
]=]
function CaptureScreenshotAction.teardown()
	isTornDown = true
end

function CaptureScreenshotAction._captureAsync(
	sendMessage: SendMessage,
	requestId: string?,
	sessionId: string,
	services: Services?,
	payload: { [string]: any }?
)
	local result = CaptureScreenshotAction._capture(services, payload or {})
	if not isTornDown then
		sendMessage(ActionReply.build(sessionId, requestId, "screenshotResult", result))
	end
end

function CaptureScreenshotAction._capture(services: Services?, payload: { [string]: any }): { [string]: any }
	-- Resolved here rather than at load, so the module still loads under Lune
	local servicesOk, servicesOrErr = pcall(function()
		return services
			or {
				runService = game:GetService("RunService"),
				captureService = game:GetService("CaptureService"),
				assetService = game:GetService("AssetService"),
				encodingService = game:GetService("EncodingService"),
			}
	end)
	if not servicesOk then
		return ActionReply.failure("CAPTURE_FAILED", `This session can't capture the viewport: {servicesOrErr}`)
	end

	local readError = ViewportCapture.checkCanRead(servicesOrErr.runService)
	if readError then
		return ActionReply.failure("CAPABILITY_NOT_SUPPORTED", readError)
	end

	local captureOk, contentId = ViewportCapture.captureAsync(servicesOrErr.captureService)
	if not captureOk then
		return ActionReply.failure(
			"CAPTURE_FAILED",
			`Studio couldn't take the screenshot: {contentId}. Make sure the Studio window is visible, then run the command again.`
		)
	end
	if contentId == nil or contentId == "" then
		return ActionReply.failure(
			"CAPTURE_FAILED",
			"Studio took no screenshot. Make sure the Studio window is visible, then run the command again."
		)
	end

	local read, code, message = ViewportCapture.readPixelsAsync(servicesOrErr.assetService, contentId, {
		region = payload.region,
		scale = payload.scale,
	})
	if not read then
		return ActionReply.failure(code or "PIXEL_READ_FAILED", message)
	end

	local encoded, formatOrErr = ViewportCapture.encodeBase64(png, servicesOrErr.encodingService, read)
	if not encoded then
		return ActionReply.failure("ENCODE_FAILED", formatOrErr)
	end

	return {
		data = encoded,
		format = formatOrErr,
		width = read.width,
		height = read.height,
	}
end

return CaptureScreenshotAction
