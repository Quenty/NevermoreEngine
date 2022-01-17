--[=[
	Throttles execution of a functon. Does both leading, and following
	@class ThrottledFunction
]=]

local ThrottledFunction = {}
ThrottledFunction.ClassName = "ThrottledFunction"
ThrottledFunction.__index = ThrottledFunction

function ThrottledFunction.new(timeoutInSeconds, func, config)
	local self = setmetatable({}, ThrottledFunction)

	self._nextCallTimeStamp = 0
	self._timeout = timeoutInSeconds or error("No timeoutInSeconds")
	self._func = func or error("No func")

	self._trailingValue = nil

	self._callLeading = true
	self._callTrailing = true

	self:_configureOrError(config)

	return self
end

function ThrottledFunction:Call(...)
	if self._trailingValue then
		-- Update the next value to be dispatched
		self._trailingValue = table.pack(...)
	elseif self._nextCallTimeStamp <= tick() then
		if self._callLeading or self._callLeadingFirstTime then
			self._callLeadingFirstTime = false
			-- Dispatch immediately
			self._nextCallTimeStamp = tick() + self._timeout
			self._func(...)
		elseif self._callTrailing then
			-- Schedule for trailing at exactly timeout
			self._trailingValue = table.pack(...)
			task.delay(self._timeout, function()
				if self.Destroy then
					self:_dispatch()
				end
			end)
		else
			error("[ThrottledFunction.Cleanup] - Trailing and leading are both disabled")
		end
	elseif self._callLeading or self._callTrailing or self._callLeadingFirstTime then
		self._callLeadingFirstTime = false
		-- As long as either leading or trailing are set to true, we are good
		local remainingTime = self._nextCallTimeStamp - tick()
		self._trailingValue = table.pack(...)

		task.delay(remainingTime, function()
			if self.Destroy then
				self:_dispatch()
			end
		end)
	end
end

function ThrottledFunction:_dispatch()
	self._nextCallTimeStamp = tick() + self._timeout

	local trailingValue = self._trailingValue
	if trailingValue then
		-- Clear before call so we are in valid state!
		self._trailingValue = nil
		self._func(unpack(trailingValue, 1, trailingValue.n))
	end
end

function ThrottledFunction:_configureOrError(throttleConfig)
	if throttleConfig == nil then
		return
	end

	assert(type(throttleConfig) == "table", "Bad throttleConfig")

	for key, value in pairs(throttleConfig) do
		assert(type(value) == "boolean", "Bad throttleConfig entry")

		if key == "leading" then
			self._callLeading = value
		elseif key == "trailing" then
			self._callTrailing = value
		elseif key == "leadingFirstTimeOnly" then
			self._callLeadingFirstTime = value
		else
			error(("Bad key %q in config"):format(tostring(key)))
		end
	end

	assert(self._callLeading or self._callTrailing, "Cannot configure both leading and trailing disabled")
end

function ThrottledFunction:Destroy()
	self._trailingValue = nil
	self._func = nil
	setmetatable(self, nil)
end

return ThrottledFunction