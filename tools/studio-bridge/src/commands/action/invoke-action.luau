--[[
	Placeholder for a future invokeAction handler.

	The `studio-bridge action <name>` command is not yet implemented —
	action discovery and generic dispatch require further design work.

	Loaded dynamically via registerAction.
]]

local InvokeAction = {}

function InvokeAction.register(router: any)
	router:setResponseType("invokeAction", "invokeActionResult")
	router:register("invokeAction", function(_payload: { [string]: any }, _requestId: string, _sessionId: string)
		return {
			success = false,
			error = "invokeAction is not yet implemented",
		}
	end)
end

return InvokeAction
