--!strict
--[[
	@class capture-screenshot.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local EncodingService = game:GetService("EncodingService")
local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local CaptureScreenshotAction = require("capture-screenshot")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local router = ActionRouter.new()
	CaptureScreenshotAction.register(router, function() end)

	local pixels = buffer.fromstring("\255\0\0\255\0\0\255\255")
	local captureError: string? = nil
	local callsBackImmediately = false
	local isRunning = false
	local readRegion: { Vector2 }? = nil

	local services: CaptureScreenshotAction.Services = {
		runService = {
			IsRunning = function()
				return isRunning
			end,
			IsClient = function()
				return true
			end,
		},
		captureService = {
			CaptureScreenshot = function(_self, onCaptureReady: (string) -> ())
				if captureError then
					error(captureError)
				end
				if callsBackImmediately then
					onCaptureReady("rbxassetid://1")
				else
					task.defer(onCaptureReady, "rbxassetid://1")
				end
			end,
		},
		assetService = {
			CreateEditableImageAsync = function()
				return {
					Size = Vector2.new(2, 1),
					ReadPixelsBuffer = function(_self, position: Vector2, size: Vector2)
						readRegion = { position, size }
						return pixels
					end,
					Destroy = function() end,
				}
			end,
		},
		encodingService = EncodingService,
	}

	return {
		pixels = pixels,
		setCaptureError = function(message: string)
			captureError = message
		end,
		setPlaytestClient = function()
			isRunning = true
		end,
		setCallsBackImmediately = function()
			callsBackImmediately = true
		end,
		getReadRegion = function(): { Vector2 }?
			return readRegion
		end,
		captureAsync = function(payload: { [string]: any }?): { [string]: any }
			local sent: { [string]: any }? = nil
			task.spawn(CaptureScreenshotAction._captureAsync, function(message)
				sent = message
			end, "request-1", "session-1", services, payload)

			local deadline = os.clock() + 5
			while sent == nil and os.clock() < deadline do
				task.wait()
			end
			assert(sent, "captureScreenshot never replied")

			return HttpService:JSONDecode(HttpService:JSONEncode(sent))
		end,
	}
end

describe("captureScreenshot", function()
	it("should answer CAPABILITY_NOT_SUPPORTED without sendMessage", function()
		local router = ActionRouter.new()
		CaptureScreenshotAction.register(router, nil)

		local response = router:Dispatch({ type = "captureScreenshot", sessionId = "session-1", payload = {} })

		expect(response).toEqual({
			type = "screenshotResult",
			sessionId = "session-1",
			payload = {
				code = "CAPABILITY_NOT_SUPPORTED",
				message = "Screenshot capture requires a sendMessage callback",
			},
		})
	end)

	it("should send the pixels as a base64 string through JSON", function()
		local controller = setup()

		local message = controller.captureAsync()

		expect(message.type).toBe("screenshotResult")
		expect(message.requestId).toBe("request-1")
		expect(message.payload.format).toBe("rgba")
		expect(message.payload.width).toBe(2)
		expect(message.payload.height).toBe(1)
		expect(typeof(message.payload.data)).toBe("string")

		local decoded = EncodingService:Base64Decode(buffer.fromstring(message.payload.data))
		expect(buffer.tostring(decoded)).toBe(buffer.tostring(controller.pixels))
	end)

	it("should read only the region it was asked for", function()
		local controller = setup()

		local message = controller.captureAsync({ region = { 1, 0, 5, 5 } })

		expect(message.type).toBe("screenshotResult")
		expect(message.payload.width).toBe(1)
		expect(controller.getReadRegion()).toEqual({ Vector2.new(1, 0), Vector2.new(1, 1) })
	end)

	it("should answer INVALID_REGION for a region outside the capture", function()
		local controller = setup()

		local message = controller.captureAsync({ region = { 10, 10, 5, 5 } })

		expect(message.type).toBe("error")
		expect(message.payload.code).toBe("INVALID_REGION")
	end)

	it("should finish when CaptureService calls back before returning", function()
		local controller = setup()
		controller.setCallsBackImmediately()

		local message = controller.captureAsync()

		expect(message.type).toBe("screenshotResult")
	end)

	it("should answer CAPTURE_FAILED when CaptureService throws", function()
		local controller = setup()
		controller.setCaptureError("no capture permission")

		local message = controller.captureAsync()

		expect(message.type).toBe("error")
		expect(message.payload.code).toBe("CAPTURE_FAILED")
	end)

	it("should refuse a playtest client, which can't read back its captures", function()
		local controller = setup()
		controller.setPlaytestClient()

		local message = controller.captureAsync()

		expect(message.type).toBe("error")
		expect(message.payload.code).toBe("CAPABILITY_NOT_SUPPORTED")
		expect(message.payload.message).toContain("without --context")
	end)
end)
