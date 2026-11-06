--!optimize 2
--[=[
	Action that captures the Studio viewport and answers with it as base64.

	Captures, reads and encodes through the `viewport-capture` library: the
	pixels are cropped to `region` and scaled by `scale`, encoded as PNG when
	the plugin supplied an encoder (raw RGBA otherwise), and base64-encoded.

	Request: `{ type: "captureScreenshot", payload: { format?: "png", region?: { x, y, w, h }, scale? } }`
	Response: `{ type: "screenshotResult", payload: { data, format, width, height } }`

	@class CaptureScreenshotAction
]=]

local CaptureScreenshotAction = {}

type SendMessage = (message: { [string]: any }) -> ()

export type Services = {
	captureService: any,
	assetService: any,
	encodingService: any,
}

-- The plugin hands its PNG encoder over through router._vendorPng
local png: any = nil
-- Filled in by the libraries, which may be pushed after this action
local libraries: { [string]: any } = {}
local isTornDown = false

--[=[
	Registers the `captureScreenshot` handler. Capturing replies asynchronously,
	so it needs `sendMessage`.
]=]
function CaptureScreenshotAction.register(router: any, sendMessage: SendMessage?)
	isTornDown = false
	png = router._vendorPng
	router._libraries = router._libraries or {}
	libraries = router._libraries

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
	local ActionReply = libraries["action-reply"]
	if not ActionReply then
		-- Without the library there is nothing to build the reply with
		sendMessage({
			type = "error",
			sessionId = sessionId,
			requestId = if requestId ~= "" then requestId else nil,
			payload = { code = "INTERNAL_ERROR", message = "The action-reply library is not installed" },
		})
		return
	end

	local result = CaptureScreenshotAction._capture(services, payload or {}, ActionReply)
	if not isTornDown then
		sendMessage(ActionReply.build(sessionId, requestId, "screenshotResult", result))
	end
end

function CaptureScreenshotAction._capture(
	services: Services?,
	payload: { [string]: any },
	ActionReply: any
): { [string]: any }
	local ViewportCapture = libraries["viewport-capture"]
	if not ViewportCapture then
		return ActionReply.failure("INTERNAL_ERROR", "The viewport-capture library is not installed")
	end

	-- Resolved here rather than at load, so the module still loads under Lune
	local servicesOk, servicesOrErr = pcall(function()
		return services
			or {
				captureService = game:GetService("CaptureService"),
				assetService = game:GetService("AssetService"),
				encodingService = game:GetService("EncodingService"),
			}
	end)
	if not servicesOk then
		return ActionReply.failure("CAPTURE_FAILED", `Required services not available: {servicesOrErr}`)
	end

	local captureOk, contentId = ViewportCapture.captureAsync(servicesOrErr.captureService)
	if not captureOk then
		return ActionReply.failure("CAPTURE_FAILED", `CaptureService failed: {contentId}`)
	end
	if contentId == nil or contentId == "" then
		return ActionReply.failure("CAPTURE_FAILED", "CaptureService returned no content ID")
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
