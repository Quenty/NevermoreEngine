--!strict
--[=[
	@class ActionReply
]=]

local ActionReply = {}

export type Failure = {
	success: boolean,
	code: string,
	message: string,
	details: any?,
}

function ActionReply.failure(code: string, message: string?, details: any?): Failure
	return {
		success = false,
		code = code,
		message = message or code,
		details = details,
	}
end

function ActionReply.call(fn: () -> { [string]: any }): { [string]: any }
	local ok, result = xpcall(fn, debug.traceback)
	if ok then
		return result
	end
	return ActionReply.failure("INTERNAL_ERROR", tostring(result))
end

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
		payload = if isFailure
			then { code = result.code, message = result.message, details = result.details }
			else result,
	}
end

return ActionReply
