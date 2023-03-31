--[=[
	Allows unregisterable BindToClose callbacks. This is important because you can't unbind
	:BindToClose calls normally, so we need to provide another place to guarantee clean shutdowns.

	@class BindToCloseService
]=]

local require = require(script.Parent.loader).load(script)

local PromiseUtils = require("PromiseUtils")
local Symbol = require("Symbol")
local Promise = require("Promise")

local BindToCloseService = {}
BindToCloseService.ServiceName = "BindToCloseService"

function BindToCloseService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._subscriptions = {}
end

function BindToCloseService:Start()
	game:BindToClose(function()
		local promises = {}

		for _, caller in pairs(self._subscriptions) do
			local promise = caller()
			if Promise.isPromise(promise) then
				table.insert(promises, promise)
			else
				warn("[BindToCloseService.BindToClose] - Bad promise returned from close callback.")
			end
		end

		local ok, err = PromiseUtils.all(promises):Yield()
		if not ok then
			warn("[BindToCloseService] - Failed to close all", err)
		end
	end)
end

--[=[
	Binds the promise to call on close. Can be unregistered

	@param saveCallback function
	@return function -- Call to unregister callback
]=]
function BindToCloseService:RegisterPromiseOnCloseCallback(saveCallback)
	assert(type(saveCallback) == "function", "Bad saveCallback")

	local id = Symbol.named("savingCallbackId")

	self._subscriptions[id] = saveCallback

	return function()
		self._subscriptions[id] = nil
	end
end

return BindToCloseService