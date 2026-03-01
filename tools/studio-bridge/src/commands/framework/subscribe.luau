--[[
	Subscribe/Unsubscribe action handler stubs for the studio-bridge plugin.

	Echoes back the requested events without actually pushing events yet.
	This allows the server to complete subscribe/unsubscribe round-trips
	while the actual event push mechanism is implemented later.

	Protocol:
	  Request:  { type: "subscribe", payload: { events: ["stateChange", "logPush"] } }
	  Response: { type: "subscribeResult", payload: { events: ["stateChange", "logPush"] } }

	  Request:  { type: "unsubscribe", payload: { events: ["stateChange"] } }
	  Response: { type: "unsubscribeResult", payload: { events: ["stateChange"] } }
]]

local SubscribeAction = {}

function SubscribeAction.register(router: any)
	router:setResponseType("subscribe", "subscribeResult")
	router:setResponseType("unsubscribe", "unsubscribeResult")
	router:register("subscribe", function(payload: { [string]: any }, _requestId: string, _sessionId: string)
		return { events = payload.events or {} }
	end)

	router:register("unsubscribe", function(payload: { [string]: any }, _requestId: string, _sessionId: string)
		return { events = payload.events or {} }
	end)
end

return SubscribeAction
