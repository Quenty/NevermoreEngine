---
-- @classmod CancelToken
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Signal = require("Signal")

local CancelToken = {}
CancelToken.ClassName = "CancelToken"
CancelToken.__index = CancelToken

function CancelToken.new(executor)
	local self = setmetatable({}, CancelToken)

	assert(type(executor) == "function")

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

function CancelToken:ErrorIfCancelled()
	if not self.PromiseCancelled:IsPending() then
		error("[CancelToken.ErrorIfCancelled] - Cancelled")
	end
end

function CancelToken:IsCancelled()
	return self.PromiseCancelled:IsFulfilled()
end

function CancelToken:_cancel()
	self.PromiseCancelled:Resolve()
end

return CancelToken