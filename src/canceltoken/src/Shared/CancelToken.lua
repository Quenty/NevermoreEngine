--!strict
--[=[
	Cancellation token
	@class CancelToken
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local Signal = require("Signal")

local EMPTY_FUNCTION = function() end

local CancelToken = {}
CancelToken.ClassName = "CancelToken"
CancelToken.__index = CancelToken

export type Executor = (cancel: () -> (), maid: any) -> ()

export type CancelToken = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		Cancelled: Signal.Signal<()>,
		PromiseCancelled: Promise.Promise<()>,
	},
	{} :: typeof({ __index = CancelToken })
))

--[=[
	Constructs a new CancelToken

	@param executor (cancel: () -> ()) -> ()
	@return CancelToken
]=]
function CancelToken.new(executor: Executor): CancelToken
	local self = setmetatable({}, CancelToken)

	assert(type(executor) == "function", "Bad executor")

	self._maid = Maid.new()

	self.PromiseCancelled = Promise.new()
	self.Cancelled = Signal.new()

	self._maid:GiveTask(function()
		self.PromiseCancelled:Resolve()
		self.Cancelled:Fire()
		self.Cancelled:Destroy()
	end)

	self.PromiseCancelled:Then(function()
		self._maid:DoCleaning()
	end)

	executor(function()
		self:_cancel()
	end, self._maid)

	return self
end

--[=[
	Returns true if the value is a cancel token
	@param value any
	@return boolean
]=]
function CancelToken.isCancelToken(value: any): boolean
	return DuckTypeUtils.isImplementation(CancelToken, value)
end

--[=[
	Constructs a new CancelToken that cancels whenever the maid does.

	@param maid Maid
	@return CancelToken
]=]
function CancelToken.fromMaid(maid: Maid.Maid): CancelToken
	local token = CancelToken.new(EMPTY_FUNCTION)

	local taskId = maid:GiveTask(function()
		token:_cancel()
	end)

	token.PromiseCancelled:Then(function()
		maid[taskId] = nil
	end)

	return token
end

--[=[
	Cancels after the set amount of seconds

	@param seconds number
	@return CancelToken
]=]
function CancelToken.fromSeconds(seconds: number): CancelToken
	assert(type(seconds) == "number", "Bad seconds")

	return CancelToken.new(function(cancel, maid)
		maid:GiveTask(task.delay(seconds, cancel))
	end)
end

--[=[
	Errors if cancelled
]=]
function CancelToken.ErrorIfCancelled(self: CancelToken): ()
	if not self.PromiseCancelled:IsPending() then
		error("[CancelToken.ErrorIfCancelled] - Cancelled")
	end
end

--[=[
	Returns true if cancelled
	@return boolean
]=]
function CancelToken.IsCancelled(self: CancelToken): boolean
	return self.PromiseCancelled:IsFulfilled()
end

function CancelToken._cancel(self: CancelToken): ()
	self._maid:DoCleaning()
end

return CancelToken
