--!strict
--[=[
	Utility functions to work with the CoreGui
	@class CoreGuiUtils
]=]

local require = require(script.Parent.loader).load(script)

local StarterGui = game:GetService("StarterGui")

local Promise = require("Promise")

local CoreGuiUtils = {}

--[=[
	Retries setting the the core. This is required because sometimes the Core
	scripts are not initialized by the time that client code executes.

	@param tries number
	@param initialWaitTime number
	@param ... any -- parameters to set core with
	@return Promise<()>
]=]
function CoreGuiUtils.promiseRetrySetCore(tries: number, initialWaitTime: number, ...): Promise.Promise<()>
	assert(type(tries) == "number", "Bad tries")
	assert(type(initialWaitTime) == "number", "Bad initialWaitTime")

	local args = { ... }
	local n = select("#", ...)

	return Promise.spawn(function(resolve, reject)
		local waitTime = initialWaitTime

		local ok, err
		for _ = 1, tries do
			ok, err = CoreGuiUtils.tryToSetCore(unpack(args, 1, n))
			if ok then
				return resolve()
			else
				task.wait(waitTime)
				-- Exponential backoff
				waitTime = waitTime * 2
			end
		end

		if not ok then
			return reject(err)
		end

		return
	end)
end

--[=[
	Tries to invoke `StarterGui:SetCore` with the arguments specified

	@param ... any -- Args to try to call SetCore with
	@return boolean -- false if failed
	@return string? -- error, if there was one
]=]
function CoreGuiUtils.tryToSetCore(...): (boolean, string?)
	local args = {...}
	local n = select("#", ...)

	local ok, err = pcall(function()
		StarterGui:SetCore(unpack(args, 1, n))
	end)
	if not ok then
		return false, err
	end

	return true
end


return CoreGuiUtils