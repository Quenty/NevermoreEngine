--!optimize 2
--[=[
	Action that captures the Studio viewport and answers with it as base64.

	Captures with CaptureService, reads the RGBA pixels through an EditableImage,
	encodes them as PNG when the plugin supplied an encoder (raw RGBA otherwise),
	and base64-encodes the result with EncodingService.

	Request: `{ type: "captureScreenshot", payload: { format?: "png" } }`
	Response: `{ type: "screenshotResult", payload: { data, format, width, height } }`

	@class CaptureScreenshotAction
]=]

-- ReadPixelsBuffer reads at most 1024x1024
local MAX_READ_SIZE = 1024

local CaptureScreenshotAction = {}

type SendMessage = (message: { [string]: any }) -> ()

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
		function(_payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
			if not sendMessage then
				return {
					code = "CAPABILITY_NOT_SUPPORTED",
					message = "Screenshot capture requires a sendMessage callback",
				}
			end

			-- Lune has no task library, so fall back to running inline there
			local spawnOk = pcall(function()
				task.spawn(CaptureScreenshotAction._captureAsync, sendMessage, requestId, sessionId)
			end)
			if not spawnOk then
				CaptureScreenshotAction._captureAsync(sendMessage, requestId, sessionId)
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

function CaptureScreenshotAction._captureAsync(sendMessage: SendMessage, requestId: string?, sessionId: string)
	local function fail(code: string, message: string)
		sendMessage(CaptureScreenshotAction._buildMessage("error", sessionId, requestId, {
			code = code,
			message = message,
		}))
	end

	-- Resolved here rather than at load, so the module still loads under Lune
	local servicesOk, captureServiceOrErr, assetService, encodingService = pcall(function()
		return game:GetService("CaptureService"), game:GetService("AssetService"), game:GetService("EncodingService")
	end)
	if not servicesOk then
		fail("CAPTURE_FAILED", `Required services not available: {captureServiceOrErr}`)
		return
	end

	local captureOk, contentIdOrErr = CaptureScreenshotAction._captureContentIdAsync(captureServiceOrErr)
	if isTornDown then
		return
	end
	if not captureOk then
		fail("CAPTURE_FAILED", `CaptureService failed: {contentIdOrErr}`)
		return
	end

	local contentId = contentIdOrErr
	if contentId == nil or contentId == "" then
		fail("CAPTURE_FAILED", "CaptureService returned no content ID")
		return
	end

	local editableOk, editableImage = pcall(function()
		return assetService:CreateEditableImageAsync(Content.fromUri(contentId))
	end)
	if not (editableOk and editableImage) then
		fail("EDITABLE_IMAGE_FAILED", `Failed to create EditableImage from capture: {editableImage or "unknown error"}`)
		return
	end

	local readTarget, scaledImage, width, height = CaptureScreenshotAction._fitToReadLimit(assetService, editableImage)

	local pixelsOk, pixels = pcall(function()
		return readTarget:ReadPixelsBuffer(Vector2.zero, Vector2.new(width, height))
	end)

	-- Free the images right away, they hold the whole capture in memory
	pcall(editableImage.Destroy, editableImage)
	if scaledImage then
		pcall(scaledImage.Destroy, scaledImage)
	end

	if not (pixelsOk and pixels) then
		fail("PIXEL_READ_FAILED", `Failed to read pixels: {pixels or "unknown error"}`)
		return
	end

	local data = pixels
	local format = "rgba"
	if png then
		local pngOk, pngData = pcall(png.encode, pixels, { width = width, height = height })
		if pngOk and pngData then
			data = pngData
			format = "png"
		end
	end

	local encodeOk, encoded = pcall(function()
		return encodingService:Base64Encode(data)
	end)
	if not (encodeOk and encoded) then
		fail("ENCODE_FAILED", `Failed to base64 encode data: {encoded or "unknown error"}`)
		return
	end

	sendMessage(CaptureScreenshotAction._buildMessage("screenshotResult", sessionId, requestId, {
		data = encoded,
		format = format,
		width = width,
		height = height,
	}))
end

--[[
	Returns true and the capture's content id, or false and the error
	CaptureService threw. Yields until the capture callback fires.
]]
function CaptureScreenshotAction._captureContentIdAsync(captureService: any): (boolean, any)
	local callerThread = coroutine.running()
	local contentId: string? = nil

	local captureOk, captureErr = pcall(function()
		captureService:CaptureScreenshot(function(id)
			contentId = id
			task.spawn(callerThread)
		end)
	end)
	if not captureOk then
		return false, captureErr
	end

	coroutine.yield()

	return true, contentId
end

--[[
	Returns an image no larger than the read limit, scaled down from the capture
	when needed. If scaling fails, falls back to the capture's top-left corner.
]]
function CaptureScreenshotAction._fitToReadLimit(assetService: any, editableImage: any): (any, any?, number, number)
	local sourceWidth = editableImage.Size.X
	local sourceHeight = editableImage.Size.Y
	if sourceWidth <= MAX_READ_SIZE and sourceHeight <= MAX_READ_SIZE then
		return editableImage, nil, sourceWidth, sourceHeight
	end

	local scale = math.min(MAX_READ_SIZE / sourceWidth, MAX_READ_SIZE / sourceHeight)
	local width = math.floor(sourceWidth * scale)
	local height = math.floor(sourceHeight * scale)

	local scaleOk, scaledImage = pcall(function()
		local scaled = assetService:CreateEditableImage({ Size = Vector2.new(width, height) })
		scaled:DrawImageTransformed(Vector2.new(width / 2, height / 2), Vector2.new(scale, scale), 0, editableImage)
		return scaled
	end)
	if scaleOk and scaledImage then
		return scaledImage, scaledImage, width, height
	end

	return editableImage, nil, math.min(sourceWidth, MAX_READ_SIZE), math.min(sourceHeight, MAX_READ_SIZE)
end

function CaptureScreenshotAction._buildMessage(
	messageType: string,
	sessionId: string,
	requestId: string?,
	payload: { [string]: any }
): { [string]: any }
	return {
		type = messageType,
		sessionId = sessionId,
		requestId = if requestId ~= "" then requestId else nil,
		payload = payload,
	}
end

return CaptureScreenshotAction
