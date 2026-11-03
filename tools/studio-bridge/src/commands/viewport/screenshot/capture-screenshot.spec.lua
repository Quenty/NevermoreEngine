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
	CaptureScreenshotAction.register(ActionRouter.new(), function() end)

	local pixels = buffer.fromstring("\255\0\0\255\0\0\255\255")
	local captureError: string? = nil
	local callsBackImmediately = false

	local services: CaptureScreenshotAction.Services = {
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
					ReadPixelsBuffer = function()
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
		setCallsBackImmediately = function()
			callsBackImmediately = true
		end,
		captureAsync = function(): { [string]: any }
			local sent: { [string]: any }? = nil
			task.spawn(CaptureScreenshotAction._captureAsync, function(message)
				sent = message
			end, "request-1", "session-1", services)

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
end)
