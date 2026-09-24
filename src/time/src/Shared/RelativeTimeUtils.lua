--!strict
--[=[
	Describes the distance between two times in words: `in 3 hours`, `a day ago`, `2 months`.

	@class RelativeTimeUtils
]=]

local require = require(script.Parent.loader).load(script)

local Time = require("Time")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local RelativeTimeUtils = {}

-- Fractional months in (dateTime - other), calendar aware. Anchors on whole months, then adds the fraction of the month the remainder covers.
function RelativeTimeUtils._monthDiff(dateTime: DateTime, other: DateTime): number
	local a = Time._toUniversalTime(dateTime)
	local b = Time._toUniversalTime(other)
	if a.Day < b.Day then
		return -RelativeTimeUtils._monthDiff(other, dateTime)
	end

	local wholeMonthDiff = (b.Year - a.Year) * 12 + (b.Month - a.Month)
	local anchor = Time.add(dateTime, wholeMonthDiff, "month")
	local remainder = other.UnixTimestampMillis - anchor.UnixTimestampMillis
	local isBeforeAnchor = remainder < 0
	local anchor2 = Time.add(dateTime, wholeMonthDiff + (if isBeforeAnchor then -1 else 1), "month")
	local monthLength = math.abs(anchor2.UnixTimestampMillis - anchor.UnixTimestampMillis)
	local fraction = if monthLength == 0 then 0 else remainder / monthLength

	return -(wholeMonthDiff + fraction)
end

-- (dateTime - other) in the given unit, fractional
function RelativeTimeUtils._diff(dateTime: DateTime, other: DateTime, unit: Time.TimeUnit): number
	local normalized = Time._normalizeUnit(unit)
	local millis = dateTime.UnixTimestampMillis - other.UnixTimestampMillis

	if normalized == "second" then
		return millis / 1000
	elseif normalized == "minute" then
		return millis / 60000
	elseif normalized == "hour" then
		return millis / 3600000
	elseif normalized == "day" then
		return millis / 86400000
	elseif normalized == "week" then
		return millis / 604800000
	elseif normalized == "month" then
		return RelativeTimeUtils._monthDiff(dateTime, other)
	elseif normalized == "year" then
		return RelativeTimeUtils._monthDiff(dateTime, other) / 12
	else
		error(string.format("Bad relative time unit %q", normalized))
	end
end

--[=[
	One step of the relative time scale. `key` picks the string, `limit` is the
	largest rounded amount this step accepts (omit for the last step), and `unit` is one of
	[Time.TimeUnit] other than milliseconds or quarters. A step without a unit reuses the
	previous step's diff, which is how `45..89 seconds` becomes `a minute`.

	@interface RelativeTimeThreshold
	.key string
	.limit number?
	.unit TimeUnit?
	@within RelativeTimeUtils
]=]
export type RelativeTimeThreshold = { key: string, limit: number?, unit: Time.TimeUnit? }

--[=[
	See [TimeLocalizationUtils.RelativeTimeStringOverrides].

	@type RelativeTimeStringOverrides TimeLocalizationUtils.RelativeTimeStringOverrides
	@within RelativeTimeUtils
]=]
export type RelativeTimeStringOverrides = TimeLocalizationUtils.RelativeTimeStringOverrides

--[=[
	Options for [RelativeTimeUtils.from], [RelativeTimeUtils.to], [RelativeTimeUtils.fromNow] and [RelativeTimeUtils.toNow].

	@interface RelativeTimeOptions
	.withoutSuffix boolean? -- Drop the `in` / `ago` wrapper
	.thresholds { RelativeTimeThreshold }? -- Replaces the default scale
	.rounding ((number) -> number)? -- Applied to the absolute amount, defaults to round half up
	.locale string? -- Picks the strings through [TimeLocalizationUtils], defaults to English
	.strings RelativeTimeStringOverrides? -- Overrides or extends the locale's strings keyed by threshold key, plus `future` and `past`
	@within RelativeTimeUtils
]=]
export type RelativeTimeOptions = {
	withoutSuffix: boolean?,
	locale: string?,
	thresholds: { RelativeTimeThreshold }?,
	rounding: ((number) -> number)?,
	strings: RelativeTimeStringOverrides?,
}

-- Default scale: seconds, then minutes, hours, days, months and years
local RELATIVE_TIME_THRESHOLDS: { RelativeTimeThreshold } = {
	{ key = "s", limit = 44, unit = "second" },
	{ key = "m", limit = 89 },
	{ key = "mm", limit = 44, unit = "minute" },
	{ key = "h", limit = 89 },
	{ key = "hh", limit = 21, unit = "hour" },
	{ key = "d", limit = 35 },
	{ key = "dd", limit = 25, unit = "day" },
	{ key = "M", limit = 45 },
	{ key = "MM", limit = 10, unit = "month" },
	{ key = "y", limit = 17 },
	{ key = "yy", unit = "year" },
}

function RelativeTimeUtils._roundHalfUp(value: number): number
	return math.floor(value + 0.5)
end

function RelativeTimeUtils._getRelativeTimeString(
	options: RelativeTimeOptions?,
	key: string
): TimeLocalizationUtils.RelativeTimeString
	local overrides = if options then options.strings else nil
	local localeStrings: any =
		TimeLocalizationUtils.getRelativeTimeStringsForLocale(if options then options.locale else nil)
	local value = (if overrides then overrides[key] else nil) or localeStrings[key]
	assert(value, string.format("No relative time string for %q", key))
	return value
end

-- Describes (dateTime - other): positive is the future.
function RelativeTimeUtils._relativeTime(dateTime: DateTime, other: DateTime, options: RelativeTimeOptions?): string
	local thresholds = (if options then options.thresholds else nil) or RELATIVE_TIME_THRESHOLDS
	local rounding = (if options then options.rounding else nil) or RelativeTimeUtils._roundHalfUp

	local withoutSuffix = if options then options.withoutSuffix == true else false

	local result = 0
	local isFuture = false
	local out = ""

	for index, threshold in thresholds do
		if threshold.unit then
			result = RelativeTimeUtils._diff(dateTime, other, threshold.unit)
		end

		local amount = rounding(math.abs(result))
		isFuture = result > 0

		if threshold.limit == nil or amount <= threshold.limit then
			-- "1 minutes" reads as "a minute", "0 seconds" as "a few seconds"
			local resolved = if amount <= 1 and index > 1 then thresholds[index - 1] else threshold
			local format = RelativeTimeUtils._getRelativeTimeString(options, resolved.key)
			if type(format) == "function" then
				out = format(amount, withoutSuffix, resolved.key, isFuture)
			else
				out = string.gsub(format, "%%d", tostring(amount))
			end
			break
		end
	end

	if withoutSuffix then
		return out
	end

	local template = RelativeTimeUtils._getRelativeTimeString(options, if isFuture then "future" else "past")
	assert(type(template) == "string", "future and past must be strings")
	local formatted = string.gsub(template, "%%s", function()
		return out
	end)

	return formatted
end

--[=[
	Describes how far `currentTime` is from `compareTo`: a later time reads
	`in a day`, an earlier one `a day ago`. See [RelativeTimeOptions] to drop the suffix or
	change the scale.

	```lua
	print(RelativeTimeUtils.from("2025-09-23T00:00:00Z", "2025-09-22T00:00:00Z")) --> in a day
	print(RelativeTimeUtils.from("2025-09-22T00:00:00Z", "2025-09-23T00:00:00Z", { withoutSuffix = true })) --> a day
	```
]=]
function RelativeTimeUtils.from(
	currentTime: Time.DateTimeLike,
	compareTo: Time.DateTimeLike,
	options: RelativeTimeOptions?
): string
	return RelativeTimeUtils._relativeTime(Time._toDateTime(currentTime), Time._toDateTime(compareTo), options)
end

--[=[
	Describes how far `compareTo` is from `currentTime`. The mirror of
	[RelativeTimeUtils.from]: `RelativeTimeUtils.to(a, b)` equals `RelativeTimeUtils.from(b, a)`.
]=]
function RelativeTimeUtils.to(
	currentTime: Time.DateTimeLike,
	compareTo: Time.DateTimeLike,
	options: RelativeTimeOptions?
): string
	return RelativeTimeUtils._relativeTime(Time._toDateTime(compareTo), Time._toDateTime(currentTime), options)
end

--[=[
	Describes how far `currentTime` is from now: `3 hours ago`.
]=]
function RelativeTimeUtils.fromNow(currentTime: Time.DateTimeLike, options: RelativeTimeOptions?): string
	return RelativeTimeUtils.from(currentTime, nil, options)
end

--[=[
	Describes how far now is from `currentTime`: `in 3 hours` for a time
	three hours in the past.
]=]
function RelativeTimeUtils.toNow(currentTime: Time.DateTimeLike, options: RelativeTimeOptions?): string
	return RelativeTimeUtils.to(currentTime, nil, options)
end

return RelativeTimeUtils
