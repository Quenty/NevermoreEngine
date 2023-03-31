--[=[
	Cancellation token
	@class CancelToken
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Signal = require("Signal")

local CancelToken = {}
CancelToken.ClassName = "CancelToken"
CancelToken.__index = CancelToken

--[=[
	Constructs a new CancelToken

	@param executor (cancel: () -> ()) -> ()
	@return CancelToken
]=]
function CancelToken.new(executor)
	local self = setmetatable({}, CancelToken)

	assert(type(executor) == "function", "Bad executor")

	self.PromiseCancelled = Promise.new()

	self.Cancelled = Signal.new()

	self.PromiseCancelled:Then(function()
		self.Cancelled:Fire()
		self.Cancelled:Destroy()
	end)

	executor(function()
		self:_cancel()
	end)

	return self
end

--[=[
	Returns true if the value is a cancel token
	@param value any
	@return boolean
]=]
function CancelToken.isCancelToken(value)
	return type(value) == "table"
		and getmetatable(value) == CancelToken
end

local EMPTY_FUNCTION = function() end

--[=[
	Constructs a new CancelToken that cancels whenever the maid does.

	@param maid Maid
	@return CancelToken
]=]
function CancelToken.fromMaid(maid)
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
	Errors if cancelled
]=]
function CancelToken:ErrorIfCancelled()
	if not self.PromiseCancelled:IsPending() then
		error("[CancelToken.ErrorIfCancelled] - Cancelled")
	end
end

--[=[
	Returns true if cancelled
	@return boolean
]=]
function CancelToken:IsCancelled()
	return self.PromiseCancelled:IsFulfilled()
end

function CancelToken:_cancel()
	self.PromiseCancelled:Resolve()
end

return CancelToken