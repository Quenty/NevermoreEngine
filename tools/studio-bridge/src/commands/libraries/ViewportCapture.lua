--!strict
--[=[
	@class ViewportCapture
]=]

local MAX_READ_SIZE = 1024

local ViewportCapture = {}

export type ReadOptions = {
	region: { number }?,
	scale: number?,
}

export type Pixels = {
	pixels: buffer,
	width: number,
	height: number,
}

function ViewportCapture.checkCanRead(runService: any): string?
	if runService:IsRunning() and runService:IsClient() then
		return "A playtest client can't read back its screenshot's pixels. Run the command without --context to capture Edit."
	end
	return nil
end

function ViewportCapture.checkRegion(region: { number }?, viewportSize: Vector2): string?
	local regionMin = ViewportCapture._clampRegion(region, viewportSize)
	if regionMin then
		return nil
	end
	return ViewportCapture._describeOutside(region, viewportSize)
end

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
		return nil, `Couldn't encode the screenshot: {encoded or "no reason given"}`
	end
	return encoded, format
end

function ViewportCapture.requestCapture(captureService: any, onReady: (contentId: string) -> ()): (boolean, any)
	return pcall(function()
		captureService:CaptureScreenshot(onReady)
	end)
end

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

	pcall(editableImage.Destroy, editableImage)
	if scaledImage then
		pcall(scaledImage.Destroy, scaledImage)
	end

	if not (pixelsOk and pixels) then
		return nil,
			"PIXEL_READ_FAILED",
			`Studio couldn't read the screenshot's pixels: {pixels or "no reason given"}. Run the command again.`
	end

	return {
		pixels = pixels,
		width = width,
		height = height,
	}
end

function ViewportCapture._describeOutside(region: { number }?, size: Vector2): string
	local described = if region then table.concat(region, ",") else "(none)"
	return `--region {described} is outside the {size.X}x{size.Y} viewport. Give one inside it, e.g. 0,0,{size.X},{size.Y}.`
end

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
