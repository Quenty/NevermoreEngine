--- Throttles execution of a functon. Does both leading, and following
-- @classmod ThrottledFunction

local ThrottledFunction = {}
ThrottledFunction.ClassName = "ThrottledFunction"
ThrottledFunction.__index = ThrottledFunction

function ThrottledFunction.new(timeoutInSeconds, func, config)
	local self = setmetatable({}, ThrottledFunction)

	self._nextCallPoint = 0
	self._timeout = timeoutInSeconds or error("No timeoutInSeconds")
	self._func = func or error("No func")

	self._lastArgs = nil
	self._lastArgsN = nil

	self._callLeadingEnabled = true
	self._callTrailingEnabled = true

	return self
end

function ThrottledFunction:ConfigureOrError(throttleConfig)
	if type(throttleConfig) == "table" then
		if type(throttleConfig.leading) == "boolean" then
			self:SetLeadingEnabled(throttleConfig.leading)
		elseif throttleConfig.leading ~= nil then
			error("Bad throttleConfigleading value")
		end

		if type(throttleConfig.trailing) == "boolean" then
			self:SetTrailingEnabled(throttleConfig.trailing)
		elseif throttleConfig.trailing ~= nil then
			error("Bad throttleConfig.trailing value")
		end
	elseif throttleConfig ~= nil then
		error("Bad throttleConfig")
	end
end

function ThrottledFunction:SetLeadingEnabled(leadingEnabled)
	assert(type(leadingEnabled) == "boolean")
	self._callLeadingEnabled = leadingEnabled
end

function ThrottledFunction:SetTrailingEnabled(trailingEnabled)
	assert(type(trailingEnabled) == "boolean")
	self._callTrailingEnabled = trailingEnabled
end

function ThrottledFunction:Call(...)
	if self._nextCallPoint <= tick() and (not self._lastArgs) then
		-- Call leading
		self._nextCallPoint = tick() + self._timeout
		if self._callLeadingEnabled then
			self._func(...)
		end
		return
	end

	-- We need to defer calling...
	local prevLastArgs = self._lastArgs

	self._lastArgs = {...}
	self._lastArgsN = select("#", ...)

	if not prevLastArgs then
		-- Call trailing
		delay(self._nextCallPoint - tick(), function()
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

	if self._callTrailingEnabled then
		self._func(unpack(args, 1, n))
	end
end

function ThrottledFunction:Cancel()
	self._lastArgs = nil
	self._lastArgsN = nil
end

function ThrottledFunction:Destroy()
	self:Cancel()
end

return ThrottledFunction