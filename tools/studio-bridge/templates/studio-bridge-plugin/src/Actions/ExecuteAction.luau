--[[
	Execute action handler for the studio-bridge plugin.

	Compiles and runs Luau code received from the server, returning a
	scriptComplete response on success or an error response on failure.

	This module has no Roblox dependencies and is testable under Lune.
]]

--[=[
	Handle an execute request by compiling and running the provided code.

	@param payload Table with a `code` field containing the Luau source to execute.
	@param requestId The request ID to echo back in the response.
	@param _sessionId The session ID (unused by this handler).
	@return Response payload table with `success = true`, or nil to let the
	        ActionRouter wrap it. Returns an error table when code is missing
	        or compilation/runtime fails.
]=]
local function handleExecute(
	payload: { [string]: any },
	requestId: string,
	_sessionId: string
): { [string]: any }?
	local code = payload and payload.code

	if not code or type(code) ~= "string" then
		return { success = false, error = "Missing code in execute request" }
	end

	local compileOk, fnOrErr = pcall(loadstring, code)
	if not compileOk then
		return { success = false, error = "Compile error: " .. tostring(fnOrErr) }
	end
	if not fnOrErr then
		return { success = false, error = "Compile error: unknown" }
	end

	local fn = fnOrErr

	local success, runtimeError = pcall(fn)
	if not success then
		return { success = false, error = "Runtime error: " .. tostring(runtimeError) }
	end

	return { success = true }
end

return handleExecute
