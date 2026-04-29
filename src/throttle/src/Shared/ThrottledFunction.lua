--!strict
--[=[
	Throttles execution of a function with configurable leading and trailing behavior.
	@class ThrottledFunction
]=]

--[=[
	@interface ThrottleConfig
	.leading boolean? -- If true, will dispatch immediately after creating this ThrottledFunction.
	.trailing boolean? -- If true, will dispatch after the timeout with the latest-called args.
	.leadingFirstTimeOnly boolean? -- If true, will dispatch immediately after creating this ThrottledFunction, but from then on, will begin the <timeout> window upon manual call
	and delay dispatch until <timeout> seconds have passed (with latest-called args).
	@within ThrottledFunction
]=]
export type ThrottleConfig = {
	leading: boolean?,
	trailing: boolean?,
	leadingFirstTimeOnly: boolean?,
}

local ThrottledFunction = {}
ThrottledFunction.ClassName = "ThrottledFunction"
ThrottledFunction.__index = ThrottledFunction

export type Func<T...> = (T...) -> ...any

export type ThrottledFunction<T...> = typeof(setmetatable(
	{} :: {
		_nextCallTimeStamp: number,
		_timeout: number,
		_func: Func<T...>,
		_trailingValue: any,
		_callLeading: boolean,
		_callTrailing: boolean,
		_callLeadingFirstTime: boolean?,
		_delayedDispatchThread: thread?,
	},
	{} :: typeof({ __index = ThrottledFunction })
))

--[=[
	@function new
	@within ThrottledFunction
	@param timeoutInSeconds number -- The (minimum) time in seconds to wait between each function dispatch; the "cooldown".
	@param func function -- The actual function whose calls will be throttled.
	@param config? ThrottleConfig -- The configuration for how throttling will behave.
	@return ThrottledFunction<T...>
]=]
function ThrottledFunction.new<T...>(
	timeoutInSeconds: number,
	func: Func<T...>,
	config: ThrottleConfig?
): ThrottledFunction<T...>
	local self: ThrottledFunction<T...> = setmetatable({} :: any, ThrottledFunction)

	self._nextCallTimeStamp = 0
	self._timeout = timeoutInSeconds or error("No timeoutInSeconds")
	self._func = func or error("No func")

	self._trailingValue = nil

	self._callLeading = true
	self._callTrailing = true
	self._delayedDispatchThread = nil

	self:_configureOrError(config or {
		leading = true,
		trailing = true,
	})

	return self
end

--[=[
	If leading = true, will enable Call() dispatching immediately after creating this ThrottledFunction.
	Else, will have to wait <timeout> seconds before it dispatches with the latest-called args.

	If trailing = true, will dispatch after the timeout with the latest-called args.
	Else, will not automatically dispatch, and must manually call again after <timeout> seconds.

	If leadingFirstTimeOnly = true, will enable Call() dispatching immediately after creating this
	ThrottledFunction, but from then on, will begin the <timeout> window upon manual call
	and delay dispatch until <timeout> seconds have passed (with latest-called args).

	@function Call
	@within ThrottledFunction
]=]
function ThrottledFunction.Call<T...>(self: ThrottledFunction<T...>, ...: T...)
	local now = os.clock()

	if self._trailingValue then
		-- If it's not nil, we're likely in the middle of the cooldown window
		-- so all we can do is update the trailing value, waiting for the delayed dispatch to reset it to nil.
		self._trailingValue = table.pack(...)
		return
	end

	if self._nextCallTimeStamp <= now then
		-- We're outside the cooldown window
		if self._callLeading or self._callLeadingFirstTime then
			-- Dispatch immediately
			self._callLeadingFirstTime = false
			self._nextCallTimeStamp = now + self._timeout
			self._func(...)
		elseif self._callTrailing then
			-- Leading is disabled, but trailing is enabled; schedule for trailing.
			self:_scheduleTrailing(self._timeout, ...)
		else
			error("[ThrottledFunction.Call] - Trailing and leading are both disabled")
		end
		return
	end

	if self._callTrailing then
		-- We have no trailing value; it was dispatched a bit ago, or we just created this ThrottledFunction.
		-- We're inside the cooldown window, so it's not dispatched/created that far ago. (we can't dispatch immediately.)
		-- We should supply a trailing value, without immediately dispatching.
		self._callLeadingFirstTime = false
		local remainingTime = math.max(0, self._nextCallTimeStamp - now)
		self:_scheduleTrailing(remainingTime, ...)
	end
	-- But if we don't have trailing, best to ignore the call (the args are dropped.)
end

ThrottledFunction.__call = ThrottledFunction.Call

function ThrottledFunction._scheduleTrailing<T...>(self: ThrottledFunction<T...>, delayTime: number, ...: T...)
	self._trailingValue = table.pack(...)
	if self._delayedDispatchThread then
		task.cancel(self._delayedDispatchThread)
	end
	self._delayedDispatchThread = task.delay(delayTime, function()
		if self.Destroy then
			self:_dispatch()
		end
	end)
end

function ThrottledFunction._dispatch<T...>(self: ThrottledFunction<T...>)
	self._nextCallTimeStamp = os.clock() + self._timeout
	self._delayedDispatchThread = nil

	local trailingValue = self._trailingValue
	if trailingValue then
		-- Clear before call so we are in valid state!
		self._trailingValue = nil
		self._func(unpack(trailingValue, 1, trailingValue.n))
	end
end

function ThrottledFunction._configureOrError<T...>(self: ThrottledFunction<T...>, throttleConfig: ThrottleConfig)
	if throttleConfig == nil then
		return
	end

	assert(type(throttleConfig) == "table", "Bad throttleConfig")

	for key, value in throttleConfig do
		assert(type(value) == "boolean", "Bad throttleConfig entry")

		if key == "leading" then
			self._callLeading = value
		elseif key == "trailing" then
			self._callTrailing = value
		elseif key == "leadingFirstTimeOnly" then
			self._callLeadingFirstTime = value
		else
			error(string.format("Bad key %q in config", tostring(key)))
		end
	end

	assert(self._callLeading or self._callTrailing, "Cannot configure both leading and trailing disabled")
end

--[=[
	Cancels any pending trailing calls.

	@function Destroy
	@within ThrottledFunction
]=]
function ThrottledFunction.Destroy<T...>(self: ThrottledFunction<T...>)
	local private: any = self
	private._trailingValue = nil
	private._func = nil
	if private._delayedDispatchThread then
		task.cancel(private._delayedDispatchThread)
	end
	private._delayedDispatchThread = nil
	setmetatable(private, nil)
end

return ThrottledFunction
