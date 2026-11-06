--!strict
--[=[
	Library for actions that reply on their own through `sendMessage`, after
	yielding, rather than through the router: it builds the same messages the
	router would, so a failure still arrives as an `error` message.

	Pushed like an action, but registers no handlers: it puts itself on
	`router._libraries` for the actions to look up when a request arrives.

	@class ActionReply
]=]

local ActionReply = {}

export type Failure = {
	success: boolean,
	code: string,
	message: string,
}

--[=[
	Makes the library available to actions as `router._libraries["action-reply"]`.
]=]
function ActionReply.register(router: any)
	router._libraries = router._libraries or {}
	router._libraries["action-reply"] = ActionReply
end

--[=[
	Returns a failure result, which `build` turns into an `error` message. The
	router does the same with a handler that returns one.
]=]
function ActionReply.failure(code: string, message: string?): Failure
	return {
		success = false,
		code = code,
		message = message or code,
	}
end

--[=[
	Returns the message answering a request with `result`: an `error` message
	for a failure, otherwise `responseType` carrying the result.
]=]
function ActionReply.build(
	sessionId: string,
	requestId: string?,
	responseType: string,
	result: { [string]: any }
): { [string]: any }
	local isFailure = result.success == false
	return {
		type = if isFailure then "error" else responseType,
		sessionId = sessionId,
		requestId = if requestId ~= "" then requestId else nil,
		payload = if isFailure then { code = result.code, message = result.message } else result,
	}
end

return ActionReply
