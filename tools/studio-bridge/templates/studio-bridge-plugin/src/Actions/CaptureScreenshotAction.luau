--[[
	CaptureScreenshot action handler stub for the studio-bridge plugin.

	Viewport screenshot capture via CaptureService/EditableImage is not
	reliably available in the plugin context. This stub registers a handler
	that returns a CAPABILITY_NOT_SUPPORTED error so the server gets a clean
	error instead of UNKNOWN_REQUEST.

	Protocol:
	  Request:  { type: "captureScreenshot", payload: {} }
	  Response: { type: "error", payload: { code: "CAPABILITY_NOT_SUPPORTED", message: "..." } }
]]

local CaptureScreenshotAction = {}

function CaptureScreenshotAction.register(router: any, sendMessage: ((msg: { [string]: any }) -> ())?)
	router:register("captureScreenshot", function(_payload: { [string]: any }, requestId: string, sessionId: string)
		local errorMsg = {
			type = "error",
			sessionId = sessionId,
			payload = {
				code = "CAPABILITY_NOT_SUPPORTED",
				message = "Screenshot capture is not available in the plugin context. Use Studio's built-in screenshot tools instead.",
			},
		}
		if requestId ~= nil and requestId ~= "" then
			errorMsg.requestId = requestId
		end

		if sendMessage then
			sendMessage(errorMsg)
		end
		-- Return nil so the ActionRouter does not generate a wrapped response.
		-- The error message was sent directly via sendMessage.
		return nil
	end)
end

return CaptureScreenshotAction
