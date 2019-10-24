--- Throttles execution of a functon
-- @classmod ThrottledFunction

local ThrottledFunction = {}
ThrottledFunction.ClassName = "ThrottledFunction"
ThrottledFunction.__index = ThrottledFunction

function ThrottledFunction.new(timeoutInSeconds, func)
	local self = setmetatable({}, ThrottledFunction)

	self._nextCallPoint = 0
	self._timeout = timeoutInSeconds or error("No timeoutInSeconds")
	self._func = func or error("No func")

	return self
end

function ThrottledFunction:Call(...)
	if self._nextCallPoint <= tick() then
		self._nextCallPoint = tick() + self._timeout
		self._func(...)
		return
	end

	-- We need to defer calling...
	local prevLastArgs = self._lastArgs

	self._lastArgs = {...}
	self._lastArgsN = select("#", ...)

	if not prevLastArgs then
		delay(tick() - self._nextCallPoint, function()
			self:_executeThrottled()
		end)
	end
end

function ThrottledFunction:_executeThrottled()
	local args, n = self._lastArgs, self._lastArgsN
	self._lastArgs = nil
	self._lastArgsN = nil
	self._nextCallPoint = tick() + self._timeout
	if not args then
		return
	end

	self._func(unpack(args, 1, n))
end

function ThrottledFunction:Cancel()
	self._lastArgs = nil
	self._lastArgsN = nil
end

function ThrottledFunction:Destroy()
	self:Cancel()
end

return ThrottledFunction