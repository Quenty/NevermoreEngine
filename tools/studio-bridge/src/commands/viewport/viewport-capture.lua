--!strict
--[=[
	Library that captures the Studio viewport and reads a capture's pixels,
	shared by `captureScreenshot` and `recordViewport`.

	- CaptureService accepts about one request every few frames and silently
	  drops the rest, never calling them back. A capture it accepts shows the
	  frame it was requested in, though its callback fires frames later.
	- Reading crops to a region of the capture, then scales it. ReadPixelsBuffer
	  reads at most 1024x1024, so a larger result is scaled down to fit.

	Pushed like an action, but registers no handlers: it puts itself on
	`router._libraries` for the actions to look up when a request arrives.

	@class ViewportCapture
]=]

-- ReadPixelsBuffer reads at most 1024x1024
local MAX_READ_SIZE = 1024

local ViewportCapture = {}

export type ReadOptions = {
	-- { x, y, width, height } in capture pixels
	region: { number }?,
	-- Applied after cropping, 1 = full size
	scale: number?,
}

export type Pixels = {
	pixels: buffer,
	width: number,
	height: number,
}

--[=[
	Makes the library available to actions as `router._libraries["viewport-capture"]`.
]=]
function ViewportCapture.register(router: any)
	router._libraries = router._libraries or {}
	router._libraries["viewport-capture"] = ViewportCapture
end

--[=[
	Returns nil when `region` overlaps a capture of `viewportSize`, else why
	not. Lets an action refuse a bad region before it captures anything.
]=]
function ViewportCapture.checkRegion(region: { number }?, viewportSize: Vector2): string?
	local regionMin = ViewportCapture._clampRegion(region, viewportSize)
	if regionMin then
		return nil
	end
	return ViewportCapture._describeOutside(region, viewportSize)
end

--[=[
	Encodes pixels as PNG with `png` (the plugin's encoder, from
	`router._vendorPng`), or leaves them raw RGBA without one, then
	base64-encodes them as a string, since JSONEncode turns a buffer into a
	`{ t = "buffer", zbase64 }` object. Returns the string and its format, or
	nil and an error.
]=]
function ViewportCapture.encodeBase64(png: any?, encodingService: any, image: Pixels): (string?, string)
	local data = image.pixels
	local format = "rgba"
	if png then
		local pngOk, pngData = pcall(png.encode, image.pixels, { width = image.width, height = image.height })
		if pngOk and pngData then
			data = pngData
			format = "png"
		end
	end

	local encodeOk, encoded = pcall(function()
		return buffer.tostring(encodingService:Base64Encode(data))
	end)
	if not (encodeOk and encoded) then
		return nil, `Failed to base64 encode data: {encoded or "unknown error"}`
	end
	return encoded, format
end

--[=[
	Requests a capture without waiting for it. Returns false and the error
	CaptureService threw, if it threw.
]=]
function ViewportCapture.requestCapture(captureService: any, onReady: (contentId: string) -> ()): (boolean, any)
	return pcall(function()
		captureService:CaptureScreenshot(onReady)
	end)
end

--[=[
	Returns true and the capture's content id, or false and the error
	CaptureService threw. Yields until the capture callback fires.
]=]
function ViewportCapture.captureAsync(captureService: any): (boolean, any)
	local callerThread = coroutine.running()
	local isWaiting = false
	local isReady = false
	local contentId: string? = nil

	local captureOk, captureErr = ViewportCapture.requestCapture(captureService, function(id)
		contentId = id
		isReady = true
		if isWaiting then
			task.spawn(callerThread)
		end
	end)
	if not captureOk then
		return false, captureErr
	end

	if not isReady then
		isWaiting = true
		coroutine.yield()
	end

	return true, contentId
end

--[=[
	Reads a capture's RGBA pixels, cropped and scaled by `options`. Returns nil,
	an error code and a message when it cannot.
]=]
function ViewportCapture.readPixelsAsync(
	assetService: any,
	contentId: string,
	options: ReadOptions?
): (Pixels?, string?, string?)
	local editableOk, editableImage = pcall(function()
		return assetService:CreateEditableImageAsync(Content.fromUri(contentId))
	end)
	if not (editableOk and editableImage) then
		return nil,
			"EDITABLE_IMAGE_FAILED",
			`Failed to create EditableImage from capture: {editableImage or "unknown error"}`
	end

	local imageSize: Vector2 = editableImage.Size
	local regionMin, regionSize = ViewportCapture._clampRegion(options and options.region, imageSize)
	if not (regionMin and regionSize) then
		pcall(editableImage.Destroy, editableImage)
		return nil, "INVALID_REGION", ViewportCapture._describeOutside(options and options.region, imageSize)
	end

	local readTarget, readOrigin, width, height, scaledImage =
		ViewportCapture._scaleRegion(assetService, editableImage, regionMin, regionSize, options and options.scale)

	local pixelsOk, pixels = pcall(function()
		return readTarget:ReadPixelsBuffer(readOrigin, Vector2.new(width, height))
	end)

	-- Free the images right away, they hold the whole capture in memory
	pcall(editableImage.Destroy, editableImage)
	if scaledImage then
		pcall(scaledImage.Destroy, scaledImage)
	end

	if not (pixelsOk and pixels) then
		return nil, "PIXEL_READ_FAILED", `Failed to read pixels: {pixels or "unknown error"}`
	end

	return {
		pixels = pixels,
		width = width,
		height = height,
	}
end

function ViewportCapture._describeOutside(region: { number }?, size: Vector2): string
	local described = if region then table.concat(region, ",") else "(none)"
	return `The region {described} is outside the {size.X}x{size.Y} viewport`
end

--[[
	Returns the region's top-left corner and size clamped to the image, the
	whole image without a region, or nil when nothing of it is inside.
]]
function ViewportCapture._clampRegion(region: { number }?, imageSize: Vector2): (Vector2?, Vector2?)
	if not region then
		return Vector2.zero, imageSize
	end

	local left = math.max(0, math.floor(region[1]))
	local top = math.max(0, math.floor(region[2]))
	local right = math.min(imageSize.X, math.floor(region[1] + region[3]))
	local bottom = math.min(imageSize.Y, math.floor(region[2] + region[4]))
	if right <= left or bottom <= top then
		return nil, nil
	end

	return Vector2.new(left, top), Vector2.new(right - left, bottom - top)
end

--[[
	Returns what to read the region from, where in it, and the size to read,
	plus a scaled image to destroy after. Scales by `scale`, and further when
	the result would pass the read limit. If scaling fails, falls back to the
	region's unscaled top-left corner.
]]
function ViewportCapture._scaleRegion(
	assetService: any,
	editableImage: any,
	regionMin: Vector2,
	regionSize: Vector2,
	requestedScale: number?
): (any, Vector2, number, number, any?)
	local scale = math.min(requestedScale or 1, MAX_READ_SIZE / regionSize.X, MAX_READ_SIZE / regionSize.Y)
	if scale >= 1 then
		return editableImage, regionMin, regionSize.X, regionSize.Y, nil
	end

	local width = math.max(1, math.floor(regionSize.X * scale))
	local height = math.max(1, math.floor(regionSize.Y * scale))

	local scaleOk, scaledImage = pcall(function()
		local scaled = assetService:CreateEditableImage({ Size = Vector2.new(width, height) })
		-- The image draws centered on the position, so offset it to center the region
		local regionCenter = regionMin + regionSize / 2
		local imageCenter = editableImage.Size / 2
		local position = Vector2.new(width, height) / 2 + (imageCenter - regionCenter) * scale
		scaled:DrawImageTransformed(position, Vector2.new(scale, scale), 0, editableImage)
		return scaled
	end)
	if scaleOk and scaledImage then
		return scaledImage, Vector2.zero, width, height, scaledImage
	end

	return editableImage, regionMin, math.min(regionSize.X, MAX_READ_SIZE), math.min(regionSize.Y, MAX_READ_SIZE), nil
end

return ViewportCapture
