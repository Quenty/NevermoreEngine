--!optimize 2
--[[
	CaptureScreenshot action handler for the studio-bridge plugin.

	Captures the Studio viewport using CaptureService, loads the result into
	an EditableImage to read raw RGBA pixels, encodes as PNG via png-luau,
	base64-encodes the PNG, and sends it over the WebSocket.

	Protocol:
	  Request:  { type: "captureScreenshot", payload: { format?: "png" } }
	  Response: { type: "screenshotResult", payload: { data, format, width, height } }
]]

-- PNG encoder is injected via router._vendorPng (set by the plugin before
-- actions are pushed). Falls back gracefully to raw RGBA if unavailable.
local _png = nil
local _disposed = false

local CaptureScreenshotAction = {}

-- ---------------------------------------------------------------------------
-- Base64 encoder for buffer data
-- ---------------------------------------------------------------------------

-- Pre-compute lookup: index 0..63 → ASCII byte
local ENCODE_LUT: buffer = buffer.create(64)
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 0, 63 do
		buffer.writeu8(ENCODE_LUT, i, string.byte(chars, i + 1))
	end
end

-- Encode a buffer as a base64 string. Uses buffer I/O throughout for speed.
local function base64Encode(buf: buffer): string
	local len = buffer.len(buf)
	local outLen = math.ceil(len / 3) * 4
	local out = buffer.create(outLen)
	local outIdx = 0

	-- Localize for tight loop performance
	local readu8 = buffer.readu8
	local writeu8 = buffer.writeu8
	local lut = ENCODE_LUT
	local rshift = bit32.rshift
	local band = bit32.band

	-- Process full 3-byte groups
	local fullLen = len - (len % 3)
	for i = 0, fullLen - 1, 3 do
		local b0 = readu8(buf, i)
		local b1 = readu8(buf, i + 1)
		local b2 = readu8(buf, i + 2)
		local n = b0 * 65536 + b1 * 256 + b2

		writeu8(out, outIdx, readu8(lut, rshift(n, 18)))
		writeu8(out, outIdx + 1, readu8(lut, band(rshift(n, 12), 63)))
		writeu8(out, outIdx + 2, readu8(lut, band(rshift(n, 6), 63)))
		writeu8(out, outIdx + 3, readu8(lut, band(n, 63)))
		outIdx += 4
	end

	-- Handle remaining 1 or 2 bytes
	local rem = len % 3
	if rem == 1 then
		local b0 = readu8(buf, fullLen)
		local n = b0 * 65536
		writeu8(out, outIdx, readu8(lut, rshift(n, 18)))
		writeu8(out, outIdx + 1, readu8(lut, band(rshift(n, 12), 63)))
		writeu8(out, outIdx + 2, 61) -- '='
		writeu8(out, outIdx + 3, 61) -- '='
	elseif rem == 2 then
		local b0 = readu8(buf, fullLen)
		local b1 = readu8(buf, fullLen + 1)
		local n = b0 * 65536 + b1 * 256
		writeu8(out, outIdx, readu8(lut, rshift(n, 18)))
		writeu8(out, outIdx + 1, readu8(lut, band(rshift(n, 12), 63)))
		writeu8(out, outIdx + 2, readu8(lut, band(rshift(n, 6), 63)))
		writeu8(out, outIdx + 3, 61) -- '='
	end

	return buffer.tostring(out)
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function buildResponse(sessionId: string, requestId: string?, payload: { [string]: any }): { [string]: any }
	local msg: { [string]: any } = {
		type = "screenshotResult",
		sessionId = sessionId,
		payload = payload,
	}
	if requestId ~= nil and requestId ~= "" then
		msg.requestId = requestId
	end
	return msg
end

local function buildError(sessionId: string, requestId: string?, code: string, message: string): { [string]: any }
	local msg: { [string]: any } = {
		type = "error",
		sessionId = sessionId,
		payload = { code = code, message = message },
	}
	if requestId ~= nil and requestId ~= "" then
		msg.requestId = requestId
	end
	return msg
end

-- ---------------------------------------------------------------------------
-- Core capture logic (runs in a spawned thread)
-- ---------------------------------------------------------------------------

local function captureAsync(sendMessage: (msg: { [string]: any }) -> (), requestId: string?, sessionId: string)
	-- Resolve services (deferred so the module loads in Lune test context)
	local getServiceOk, captureServiceOrErr, assetServiceOrErr = pcall(function()
		return game:GetService("CaptureService"), game:GetService("AssetService")
	end)
	if not getServiceOk then
		sendMessage(
			buildError(sessionId, requestId, "CAPTURE_FAILED", `Required services not available: {captureServiceOrErr}`)
		)
		return
	end
	local CaptureService = captureServiceOrErr
	local AssetService = assetServiceOrErr

	-- Step 1: Capture the viewport via CaptureService
	local callerThread = coroutine.running()
	local contentId: string? = nil
	local captureOk, captureErr = pcall(function()
		CaptureService:CaptureScreenshot(function(id)
			contentId = id
			task.spawn(callerThread)
		end)
	end)

	if not captureOk then
		sendMessage(buildError(sessionId, requestId, "CAPTURE_FAILED", `CaptureService failed: {captureErr}`))
		return
	end

	-- Wait for the callback
	coroutine.yield()

	if _disposed then return end

	if not contentId or contentId == "" then
		sendMessage(buildError(sessionId, requestId, "CAPTURE_FAILED", "CaptureService returned no content ID"))
		return
	end

	-- Step 2: Load into an EditableImage to read pixels
	local editableOk, editableImage = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(contentId :: string))
	end)

	if not editableOk or not editableImage then
		sendMessage(
			buildError(
				sessionId,
				requestId,
				"EDITABLE_IMAGE_FAILED",
				`Failed to create EditableImage from capture: {editableImage or "unknown error"}`
			)
		)
		return
	end

	-- Step 3: Read all pixels as RGBA buffer
	-- ReadPixelsBuffer has a 1024x1024 limit. If the screenshot is larger,
	-- scale it down into a new EditableImage that fits within the limit.
	local MAX_SIZE = 1024
	local srcWidth = editableImage.Size.X
	local srcHeight = editableImage.Size.Y
	local width = srcWidth
	local height = srcHeight

	local readTarget = editableImage
	local scaledImage = nil

	if srcWidth > MAX_SIZE or srcHeight > MAX_SIZE then
		local scale = math.min(MAX_SIZE / srcWidth, MAX_SIZE / srcHeight)
		width = math.floor(srcWidth * scale)
		height = math.floor(srcHeight * scale)

		local scaleOk, scaleResult = pcall(function()
			local scaled = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
			scaled:DrawImageTransformed(
				Vector2.new(width / 2, height / 2), -- center position
				Vector2.new(scale, scale), -- scale
				0, -- rotation
				editableImage
			)
			return scaled
		end)

		if scaleOk and scaleResult then
			scaledImage = scaleResult
			readTarget = scaleResult
		else
			-- If scaling fails, just read the top-left 1024x1024 corner
			width = math.min(srcWidth, MAX_SIZE)
			height = math.min(srcHeight, MAX_SIZE)
		end
	end

	local pixelsOk, pixelsBuf = pcall(function()
		return readTarget:ReadPixelsBuffer(Vector2.zero, Vector2.new(width, height))
	end)

	-- Clean up EditableImages immediately to free memory
	pcall(function()
		editableImage:Destroy()
	end)
	if scaledImage then
		pcall(function()
			scaledImage:Destroy()
		end)
	end

	if not pixelsOk or not pixelsBuf then
		sendMessage(
			buildError(
				sessionId,
				requestId,
				"PIXEL_READ_FAILED",
				`Failed to read pixels: {pixelsBuf or "unknown error"}`
			)
		)
		return
	end

	-- Step 4: Encode as PNG (if available) or raw RGBA, then base64
	local dataBuf = pixelsBuf
	local format = "rgba"

	if _png then
		local pngOk, pngBuf = pcall(_png.encode, pixelsBuf, { width = width, height = height })
		if pngOk and pngBuf then
			dataBuf = pngBuf
			format = "png"
		end
	end

	local encodeOk, encoded = pcall(base64Encode, dataBuf)
	if not encodeOk or not encoded then
		sendMessage(
			buildError(
				sessionId,
				requestId,
				"ENCODE_FAILED",
				`Failed to base64 encode data: {encoded or "unknown error"}`
			)
		)
		return
	end

	-- Step 5: Send the result
	sendMessage(buildResponse(sessionId, requestId, {
		data = encoded,
		format = format,
		width = width,
		height = height,
	}))
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function CaptureScreenshotAction.register(router: any, sendMessage: ((msg: { [string]: any }) -> ())?)
	_disposed = false
	router:setResponseType("captureScreenshot", "screenshotResult")
	-- Capture the PNG encoder from the router's shared deps (set by the plugin)
	_png = router._vendorPng or nil

	router:register("captureScreenshot", function(_payload: { [string]: any }, requestId: string, sessionId: string): { [string]: any }?
		if not sendMessage then
			return {
				code = "CAPABILITY_NOT_SUPPORTED",
				message = "Screenshot capture requires a sendMessage callback",
			}
		end

		-- Run asynchronously since CaptureService uses a callback.
		-- pcall guards against Lune test context where task is not available.
		local spawnOk = pcall(function()
			task.spawn(captureAsync, sendMessage, requestId, sessionId)
		end)
		if not spawnOk then
			-- Fallback: call directly (will fail on GetService in Lune)
			captureAsync(sendMessage, requestId, sessionId)
		end

		-- Return nil so ActionRouter does not generate a wrapped response
		return nil
	end)
end

function CaptureScreenshotAction.teardown()
	_disposed = true
end

return CaptureScreenshotAction
