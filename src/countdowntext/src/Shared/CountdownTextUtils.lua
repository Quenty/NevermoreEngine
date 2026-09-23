--!strict
--[=[
	Utility functions to format countdowns in-game, built on [TimeDurationUtils].

	@class CountdownTextUtils
]=]

local require = require(script.Parent.loader).load(script)

local TimeDurationUtils = require("TimeDurationUtils")

local CountdownTextUtils = {}

--[=[
	Formats a number of seconds as countdown text, showing only as many units as the remaining
	time needs: `45`, then `3:05`, then `1:02:03`, and `2 days 1:02:03` for longer waits. Each unit
	counts up to a round number before the next is used, so a one minute countdown starts at `60`,
	a one hour countdown at `60:00`, and a single day rolls into the hours as `47:15:00`.
	The `days` word is localized through [TimeDurationUtils.format]; `locale` defaults to English.
	Fractional seconds are truncated.

	```lua
	print(CountdownTextUtils.formatCountdown(0, "Now!")) --> Now!
	print(CountdownTextUtils.formatCountdown(185)) --> 3:05
	print(CountdownTextUtils.formatCountdown(3 * 86400 + 5, nil, "es-es")) --> 3 días 0:00:05
	```
]=]
function CountdownTextUtils.formatCountdown(seconds: number, whenAtZeroText: string?, locale: string?): string
	assert(type(seconds) == "number", "Bad seconds")
	assert(type(whenAtZeroText) == "string" or whenAtZeroText == nil, "Bad whenAtZeroText")
	assert(type(locale) == "string" or locale == nil, "Bad locale")

	if seconds <= 0 then
		return whenAtZeroText or "0"
	end

	return TimeDurationUtils.format(seconds, "d __ h:mm:ss", {
		locale = locale,
		trunc = true,
		-- A one minute countdown starts at 60, a one hour countdown at 60:00, and a single day
		-- reads as 24 to 47 hours since "1 day 23:15:00" is easy to misread
		limits = {
			seconds = 60,
			minutes = 60,
			hours = 47,
		},
	})
end

return CountdownTextUtils
