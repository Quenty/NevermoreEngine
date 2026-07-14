--!strict
--[=[
	Allows unregisterable BindToClose callbacks. This is important because you can't unbind
	:BindToClose calls normally, so we need to provide another place to guarantee clean shutdowns.

	@class BindToCloseService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local ServiceBag = require("ServiceBag")
local Symbol = require("Symbol")

local BindToCloseService = {}
BindToCloseService.ServiceName = "BindToCloseService"

export type BindToCloseService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_subscriptions: { [Symbol.Symbol]: () -> Promise.Promise<any> },
	},
	{} :: typeof({ __index = BindToCloseService })
))

function BindToCloseService.Init(self: BindToCloseService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._subscriptions = {}
end

function BindToCloseService.Start(self: BindToCloseService): ()
	if RunService:IsServer() then
		game:BindToClose(function()
			local ok, err = self:_promiseClose():Yield()
			if not ok then
				warn("[BindToCloseService] - Failed to close all", err)
			end
		end)

		-- TODO: Also close on cleanup here
	else
		-- This happens when running in a plugin or some other scenario....

		self._maid:GiveTask(function()
			self:_promiseClose()
		end)
	end
end

function BindToCloseService._promiseClose(self: BindToCloseService): Promise.Promise<any>
	local promises: { Promise.Promise<any> } = {}

	for _, caller in self._subscriptions do
		local promise = caller()
		if Promise.isPromise(promise) then
			table.insert(promises, promise :: any)
		else
			warn("[BindToCloseService.BindToClose] - Bad promise returned from close callback.")
		end
	end

	return PromiseUtils.all(promises)
end

--[=[
	Binds the promise to call on close. Can be unregistered

	@param saveCallback function
	@return function -- Call to unregister callback
]=]
function BindToCloseService.RegisterPromiseOnCloseCallback(
	self: BindToCloseService,
	saveCallback: () -> Promise.Promise<any>
): () -> ()
	assert(type(saveCallback) == "function", "Bad saveCallback")

	local id = Symbol.named("savingCallbackId")

	self._subscriptions[id] = saveCallback

	return function()
		self._subscriptions[id] = nil
	end
end

function BindToCloseService.Destroy(self: BindToCloseService): ()
	self._maid:DoCleaning()
end

return BindToCloseService
