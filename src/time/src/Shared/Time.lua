--!strict
--[=[
	@class Time
]=]

local require = require(script.Parent.loader).load(script)

local NumberLocalizationOrdinalUtils = require("NumberLocalizationOrdinalUtils")

local Time = {}

--[=[
	A unix timestamp in seconds (fractions are floored), a Roblox `DateTime`, an ISO 8601 string
	such as `"2025-09-22T13:00:00Z"`, or `nil` for the current time.

	@type DateTimeLike number | DateTime | string | nil
	@within Time
]=]
export type DateTimeLike = (number | DateTime | string)?

type UniversalTime = {
	Year: number,
	Month: number,
	Day: number,
	Hour: number,
	Minute: number,
	Second: number,
	Millisecond: number,
}

-- Roblox has no default locale: FormatUniversalTime errors without one and falls back to English
-- (with a warning) for one it does not know.
local DEFAULT_LOCALE = "en-us"

local DAYS_IN_MONTH = table.freeze({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })
local SECONDS_PER_DAY = 86400
local UNIX_EPOCH_JULIAN_DAY = 2440588

function Time._toDateTime(currentTime: DateTimeLike): DateTime
	if currentTime == nil then
		return DateTime.now()
	elseif typeof(currentTime) == "DateTime" then
		return currentTime
	elseif type(currentTime) == "number" then
		return DateTime.fromUnixTimestamp(math.floor(currentTime))
	elseif type(currentTime) == "string" then
		local dateTime = DateTime.fromIsoDate(currentTime)
		assert(dateTime, "Bad ISO date")
		return dateTime
	else
		error(string.format("Bad currentTime %q", typeof(currentTime)))
	end
end

function Time._toUniversalTime(currentTime: DateTimeLike): UniversalTime
	-- The engine definitions type ToUniversalTime() as { any }
	return Time._toDateTime(currentTime):ToUniversalTime() :: any
end

function Time._formatUniversal(currentTime: DateTimeLike, format: string, locale: string?): string
	return Time._toDateTime(currentTime):FormatUniversalTime(format, locale or DEFAULT_LOCALE)
end

function Time._formatUniversalNumber(currentTime: DateTimeLike, format: string): number
	local value = tonumber(Time._formatUniversal(currentTime, format))
	assert(value, "Failed to parse formatted time")
	return value
end

--[=[
	Returns a Days in months table for the given year
]=]
function Time.getDaysMonthTable(year: number): { [number]: number }
	local copy = table.clone(DAYS_IN_MONTH)

	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		copy[2] = 29
	else
		copy[2] = 28
	end

	return table.freeze(copy)
end

--[=[
	Returns the second of the given time.
]=]
function Time.getSecond(currentTime: DateTimeLike): number
	return Time._toUniversalTime(currentTime).Second
end

--[=[
	Returns the minute of the given time.
]=]
function Time.getMinute(currentTime: DateTimeLike): number
	return Time._toUniversalTime(currentTime).Minute
end

--[=[
	Returns the hour of the given time in 24-hour format.
]=]
function Time.getHour(currentTime: DateTimeLike): number
	return Time._toUniversalTime(currentTime).Hour
end

--[=[
	Returns the day of the year (1-366) for the given time.
]=]
function Time.getDay(currentTime: DateTimeLike): number
	return Time._formatUniversalNumber(currentTime, "DDD")
end

--[=[
	Returns the year for the given time.
]=]
function Time.getYear(currentTime: DateTimeLike): number
	return Time._toUniversalTime(currentTime).Year
end

--[=[
	Returns the last two digits of the year for the given time.
]=]
function Time.getYearShort(currentTime: DateTimeLike): number
	return Time.getYear(currentTime) % 100
end

--[=[
	Returns the last two digits of the year formatted as a string.
]=]
function Time.getYearShortFormatted(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "YY", locale)
end

--[=[
	Returns the month (1-12) of the given time.
]=]
function Time.getMonth(currentTime: DateTimeLike): number
	return Time._toUniversalTime(currentTime).Month
end

--[=[
	Returns the month formatted as a two-digit string.
]=]
function Time.getFormattedMonth(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "MM", locale)
end

--[=[
	Returns the day of the month (1-31) for the given time.
]=]
function Time.getDayOfTheMonth(currentTime: DateTimeLike): number
	return Time._toUniversalTime(currentTime).Day
end

--[=[
	Returns the day of the month formatted as a two-digit string.
]=]
function Time.getFormattedDayOfTheMonth(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "DD", locale)
end

--[=[
	Returns the full name of the month for the given time.
]=]
function Time.getMonthName(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "MMMM", locale)
end

--[=[
	Returns the abbreviated name of the month for the given time.
]=]
function Time.getMonthNameShort(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "MMM", locale)
end

--[=[
	Returns the Julian day number for the given time.
]=]
function Time.getJulianDate(currentTime: DateTimeLike): number
	return Time._toDateTime(currentTime).UnixTimestamp // SECONDS_PER_DAY + UNIX_EPOCH_JULIAN_DAY
end

--[=[
	Returns the day of the week as a number (0-6, starting on Sunday) for the given time.
]=]
function Time.getDayOfTheWeek(currentTime: DateTimeLike): number
	return Time._formatUniversalNumber(currentTime, "d")
end

--[=[
	Returns the full name of the day of the week for the given time.
]=]
function Time.getDayOfTheWeekName(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "dddd", locale)
end

--[=[
	Returns the abbreviated name of the day of the week for the given time.
]=]
function Time.getDayOfTheWeekNameShort(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "ddd", locale)
end

--[=[
	Returns the localized ordinal suffix for a number, for example `nd` for 22 in English.
	See [NumberLocalizationOrdinalUtils.getSuffix].
]=]
function Time.getOrdinalOfNumber(number: number, locale: string?): string
	return NumberLocalizationOrdinalUtils.getSuffix(number, locale or DEFAULT_LOCALE)
end

--[=[
	Returns the localized ordinal suffix for the day of the month for the given time.
]=]
function Time.getDayOfTheMonthOrdinal(currentTime: DateTimeLike, locale: string?): string
	return Time.getOrdinalOfNumber(Time.getDayOfTheMonth(currentTime), locale)
end

--[=[
	Returns the second formatted as a two-digit string.
]=]
function Time.getFormattedSecond(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "ss", locale)
end

--[=[
	Returns the minute formatted as a two-digit string.
]=]
function Time.getFormattedMinute(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "mm", locale)
end

--[=[
	Returns the hour in 12-hour format (1-12).
]=]
function Time.getRegularHour(currentTime: DateTimeLike): number
	return Time._formatUniversalNumber(currentTime, "h")
end

--[=[
	Returns the hour formatted as a two-digit string in 24-hour format.
]=]
function Time.getHourFormatted(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "HH", locale)
end

--[=[
	Returns the hour formatted as a two-digit string in 12-hour format.
]=]
function Time.getRegularHourFormatted(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "hh", locale)
end

--[=[
	Returns "am" or "pm" (or the locale's equivalent) based on the given time.
]=]
function Time.getamOrpm(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "a", locale)
end

--[=[
	Returns "AM" or "PM" (or the locale's equivalent) based on the given time.
]=]
function Time.getAMorPM(currentTime: DateTimeLike, locale: string?): string
	return Time._formatUniversal(currentTime, "A", locale)
end

--[=[
	Reports the time in 24-hour format as a two-digit string.
]=]
function Time.getMilitaryHour(currentTime: DateTimeLike, locale: string?): string
	return Time.getHourFormatted(currentTime, locale)
end

--[=[
	Determines if the year of the given time is a leap year.
]=]
function Time.isLeapYear(currentTime: DateTimeLike): boolean
	local year = Time.getYear(currentTime)
	return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

--[=[
	Returns the number of days in the month for the given time.
]=]
function Time.getDaysInMonth(currentTime: DateTimeLike): number
	local universalTime = Time._toUniversalTime(currentTime)
	return Time.getDaysMonthTable(universalTime.Year)[universalTime.Month]
end

--[=[
	Returns the unix timestamp in seconds for the given time.
]=]
function Time.getUnixTimestamp(currentTime: DateTimeLike): number
	return Time._toDateTime(currentTime).UnixTimestamp
end

--[=[
	A unit of time for [Time.add], [Time.subtract], [Time.startOf] and [Time.endOf], singular or
	plural, or one of the shorthands `ms`, `s`, `m`, `h`, `d`, `D`, `w`, `M`, `Q` and `y`.
	`date` is another name for `day`.

	@type TimeUnit "millisecond" | "second" | "minute" | "hour" | "day" | "week" | "month" | "quarter" | "year" | plurals | shorthands
	@within Time
]=]
export type TimeUnit =
	"millisecond"
	| "milliseconds"
	| "ms"
	| "second"
	| "seconds"
	| "s"
	| "minute"
	| "minutes"
	| "m"
	| "hour"
	| "hours"
	| "h"
	| "day"
	| "days"
	| "d"
	| "date"
	| "D"
	| "week"
	| "weeks"
	| "w"
	| "month"
	| "months"
	| "M"
	| "quarter"
	| "quarters"
	| "Q"
	| "year"
	| "years"
	| "y"

type CanonicalTimeUnit = "millisecond" | "second" | "minute" | "hour" | "day" | "week" | "month" | "quarter" | "year"

local TIME_UNIT_ALIASES: { [string]: CanonicalTimeUnit } = {
	millisecond = "millisecond",
	milliseconds = "millisecond",
	ms = "millisecond",
	second = "second",
	seconds = "second",
	s = "second",
	minute = "minute",
	minutes = "minute",
	m = "minute",
	hour = "hour",
	hours = "hour",
	h = "hour",
	day = "day",
	days = "day",
	d = "day",
	date = "day",
	D = "day",
	week = "week",
	weeks = "week",
	w = "week",
	month = "month",
	months = "month",
	M = "month",
	quarter = "quarter",
	quarters = "quarter",
	Q = "quarter",
	year = "year",
	years = "year",
	y = "year",
}

-- Units that are a fixed number of milliseconds. Month, quarter and year move on the calendar.
local TIME_UNIT_MILLISECONDS: { [string]: number } = {
	millisecond = 1,
	second = 1000,
	minute = 60000,
	hour = 3600000,
	day = 86400000,
	week = 604800000,
}

function Time._normalizeUnit(unit: TimeUnit): CanonicalTimeUnit
	local normalized = TIME_UNIT_ALIASES[unit]
	assert(normalized, string.format("Bad unit %q", tostring(unit)))
	return normalized :: CanonicalTimeUnit
end

-- Moves whole months on the calendar, clamping the day to the target month
function Time._addMonths(dateTime: DateTime, months: number): DateTime
	local universalTime = Time._toUniversalTime(dateTime)
	local monthIndex = universalTime.Month - 1 + months
	local year = universalTime.Year + monthIndex // 12
	local month = monthIndex % 12 + 1
	local day = math.min(universalTime.Day, Time.getDaysMonthTable(year)[month])

	return DateTime.fromUniversalTime(
		year,
		month,
		day,
		universalTime.Hour,
		universalTime.Minute,
		universalTime.Second,
		universalTime.Millisecond
	)
end

--[=[
	Returns a `DateTime` moved forward by `value` units. Months, quarters and
	years move on the calendar and clamp the day, so January 31st plus a month is February 28th
	(or 29th); every other unit is a fixed offset. A negative value moves backwards.

	```lua
	Time.add("2025-01-31T00:00:00Z", 1, "month") --> 2025-02-28T00:00:00Z
	Time.add(os.time(), 7, "days")
	```
]=]
function Time.add(currentTime: DateTimeLike, value: number, unit: TimeUnit): DateTime
	assert(type(value) == "number", "Bad value")

	local dateTime = Time._toDateTime(currentTime)
	local normalized = Time._normalizeUnit(unit)

	local monthsPerUnit = if normalized == "month"
		then 1
		elseif normalized == "quarter" then 3
		elseif normalized == "year" then 12
		else nil
	if monthsPerUnit then
		local wholeMonths = math.modf(value * monthsPerUnit)
		return Time._addMonths(dateTime, wholeMonths)
	end

	return DateTime.fromUnixTimestampMillis(dateTime.UnixTimestampMillis + value * TIME_UNIT_MILLISECONDS[normalized])
end

--[=[
	Returns a `DateTime` moved back by `value` units. See [Time.add].
]=]
function Time.subtract(currentTime: DateTimeLike, value: number, unit: TimeUnit): DateTime
	assert(type(value) == "number", "Bad value")

	return Time.add(currentTime, -value, unit)
end

--[=[
	Returns a `DateTime` at the first instant of the unit containing `currentTime`:
	`startOf(t, "day")` is midnight, `startOf(t, "month")` the 1st at midnight. Weeks
	start on Sunday.

	```lua
	Time.startOf("2025-09-22T13:45:30Z", "week") --> 2025-09-21T00:00:00Z
	```
]=]
function Time.startOf(currentTime: DateTimeLike, unit: TimeUnit): DateTime
	local dateTime = Time._toDateTime(currentTime)
	local normalized = Time._normalizeUnit(unit)
	local t = Time._toUniversalTime(dateTime)

	if normalized == "millisecond" then
		return dateTime
	elseif normalized == "second" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour, t.Minute, t.Second)
	elseif normalized == "minute" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour, t.Minute)
	elseif normalized == "hour" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour)
	elseif normalized == "day" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day)
	elseif normalized == "week" then
		return Time.subtract(DateTime.fromUniversalTime(t.Year, t.Month, t.Day), Time.getDayOfTheWeek(dateTime), "day")
	elseif normalized == "month" then
		return DateTime.fromUniversalTime(t.Year, t.Month)
	elseif normalized == "quarter" then
		return DateTime.fromUniversalTime(t.Year, (t.Month - 1) // 3 * 3 + 1)
	elseif normalized == "year" then
		return DateTime.fromUniversalTime(t.Year)
	else
		error(string.format("Bad unit %q", normalized))
	end
end

--[=[
	Returns a `DateTime` at the last millisecond of the unit containing `currentTime`:
	`endOf(t, "day")` is 23:59:59.999. See [Time.startOf].
]=]
function Time.endOf(currentTime: DateTimeLike, unit: TimeUnit): DateTime
	local nextStart = Time.add(Time.startOf(currentTime, unit), 1, unit)
	return DateTime.fromUnixTimestampMillis(nextStart.UnixTimestampMillis - 1)
end

--[=[
	A field of a time for [Time.get] and [Time.set], singular or plural, or one of the
	shorthands `y`, `M`, `D`, `d`, `h`, `m`, `s` and `ms`. `date` is the day of the month and
	`day` is the day of the week (0 is Sunday). `month` runs 1-12.

	@type TimeField "year" | "month" | "date" | "day" | "hour" | "minute" | "second" | "millisecond" | plurals | shorthands
	@within Time
]=]
export type TimeField =
	"year"
	| "years"
	| "y"
	| "month"
	| "months"
	| "M"
	| "date"
	| "dates"
	| "D"
	| "day"
	| "days"
	| "d"
	| "hour"
	| "hours"
	| "h"
	| "minute"
	| "minutes"
	| "m"
	| "second"
	| "seconds"
	| "s"
	| "millisecond"
	| "milliseconds"
	| "ms"

type CanonicalTimeField = "year" | "month" | "date" | "day" | "hour" | "minute" | "second" | "millisecond"

local TIME_FIELD_ALIASES: { [string]: CanonicalTimeField } = {
	year = "year",
	years = "year",
	y = "year",
	month = "month",
	months = "month",
	M = "month",
	date = "date",
	dates = "date",
	D = "date",
	day = "day",
	days = "day",
	d = "day",
	hour = "hour",
	hours = "hour",
	h = "hour",
	minute = "minute",
	minutes = "minute",
	m = "minute",
	second = "second",
	seconds = "second",
	s = "second",
	millisecond = "millisecond",
	milliseconds = "millisecond",
	ms = "millisecond",
}

function Time._normalizeField(field: TimeField): CanonicalTimeField
	local normalized = TIME_FIELD_ALIASES[field]
	assert(normalized, string.format("Bad field %q", tostring(field)))
	return normalized :: CanonicalTimeField
end

-- Like JavaScript's Date setters: a month or day past the end of its range rolls into the next
-- period, and 0 or a negative day rolls back into the previous one.
function Time._fromUniversalTimeOverflowing(
	year: number,
	month: number,
	day: number,
	hour: number,
	minute: number,
	second: number,
	millisecond: number
): DateTime
	local monthIndex = month - 1
	local firstOfMonth =
		DateTime.fromUniversalTime(year + monthIndex // 12, monthIndex % 12 + 1, 1, hour, minute, second, millisecond)

	return Time.add(firstOfMonth, day - 1, "day")
end

--[=[
	Reads one field of the given time.

	```lua
	Time.get("2025-09-22T13:45:30Z", "date") --> 22
	Time.get("2025-09-22T13:45:30Z", "day") --> 1 (Monday)
	```
]=]
function Time.get(currentTime: DateTimeLike, field: TimeField): number
	local normalized = Time._normalizeField(field)

	if normalized == "day" then
		return Time.getDayOfTheWeek(currentTime)
	end

	local t = Time._toUniversalTime(currentTime)

	if normalized == "year" then
		return t.Year
	elseif normalized == "month" then
		return t.Month
	elseif normalized == "date" then
		return t.Day
	elseif normalized == "hour" then
		return t.Hour
	elseif normalized == "minute" then
		return t.Minute
	elseif normalized == "second" then
		return t.Second
	elseif normalized == "millisecond" then
		return t.Millisecond
	else
		error(string.format("Bad field %q", normalized))
	end
end

--[=[
	Returns a `DateTime` with one field replaced. Values outside the field's
	range roll over the way JavaScript dates do: month 13 is January of the next year, date 0 is
	the last day of the previous month, hour 25 is 1am the next day. Setting `day` moves within
	the current week, so 0 is the preceding Sunday.

	```lua
	Time.set("2025-09-22T13:45:30Z", "date", 1) --> 2025-09-01T13:45:30Z
	Time.set("2025-09-22T13:45:30Z", "day", 0) --> 2025-09-21T13:45:30Z
	```
]=]
function Time.set(currentTime: DateTimeLike, field: TimeField, value: number): DateTime
	assert(type(value) == "number", "Bad value")

	local dateTime = Time._toDateTime(currentTime)
	local normalized = Time._normalizeField(field)
	local t = Time._toUniversalTime(dateTime)
	local whole = math.floor(value)

	if normalized == "year" then
		return Time._fromUniversalTimeOverflowing(whole, t.Month, t.Day, t.Hour, t.Minute, t.Second, t.Millisecond)
	elseif normalized == "month" then
		return Time._fromUniversalTimeOverflowing(t.Year, whole, t.Day, t.Hour, t.Minute, t.Second, t.Millisecond)
	elseif normalized == "date" then
		return Time._fromUniversalTimeOverflowing(t.Year, t.Month, whole, t.Hour, t.Minute, t.Second, t.Millisecond)
	elseif normalized == "day" then
		return Time.add(dateTime, whole - Time.getDayOfTheWeek(dateTime), "day")
	elseif normalized == "hour" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, whole, t.Minute, t.Second, t.Millisecond)
	elseif normalized == "minute" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour, whole, t.Second, t.Millisecond)
	elseif normalized == "second" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour, t.Minute, whole, t.Millisecond)
	elseif normalized == "millisecond" then
		return DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour, t.Minute, t.Second, whole)
	else
		error(string.format("Bad field %q", normalized))
	end
end

-- Tokens FormatUniversalTime does not offer. Documented on Time.format.
local EXTENDED_FORMAT_TOKENS: { [string]: (DateTime, string) -> string } = {
	Do = function(dateTime: DateTime, locale: string): string
		return NumberLocalizationOrdinalUtils.localize(Time.getDayOfTheMonth(dateTime), locale)
	end,
	DDDo = function(dateTime: DateTime, locale: string): string
		return NumberLocalizationOrdinalUtils.localize(Time.getDay(dateTime), locale)
	end,
	t = function(dateTime: DateTime): string
		return tostring(Time.getDaysInMonth(dateTime))
	end,
	LY = function(dateTime: DateTime): string
		return tostring(Time.isLeapYear(dateTime))
	end,
	X = function(dateTime: DateTime): string
		return tostring(Time.getUnixTimestamp(dateTime))
	end,
	J = function(dateTime: DateTime): string
		return tostring(Time.getJulianDate(dateTime))
	end,
}

-- Longest first so "DDDo" wins over "Do"
local EXTENDED_FORMAT_TOKENS_BY_LENGTH: { string } = {}
do
	for token, _ in EXTENDED_FORMAT_TOKENS do
		table.insert(EXTENDED_FORMAT_TOKENS_BY_LENGTH, token)
	end
	table.sort(EXTENDED_FORMAT_TOKENS_BY_LENGTH, function(a, b)
		return #a > #b
	end)
end

function Time._matchExtendedToken(format: string, index: number): string?
	for _, token in EXTENDED_FORMAT_TOKENS_BY_LENGTH do
		if string.sub(format, index, index + #token - 1) == token then
			return token
		end
	end

	return nil
end

--[=[
	Formats the given time. The format string is passed to
	[DateTime:FormatUniversalTime](https://create.roblox.com/docs/reference/engine/datatypes/DateTime#FormatUniversalTime)
	with the given locale, so every Roblox token works, for example `"YYYY-MM-DD HH:mm:ss"`
	or `"dddd, MMMM D"`. On top of those, these tokens are available, for example
	`"MMMM Do, YYYY"` gives `September 22nd, 2025`. Their spellings avoid Roblox's own letters,
	so `S` (fractional seconds) and `L` (locale composites) keep their Roblox meaning.

	| Token | Output |
	| ----- | ------ |
	| `Do` | Day of the month as a localized ordinal, e.g. `22nd` or `22e` |
	| `DDDo` | Day of the year as a localized ordinal, e.g. `265th` |
	| `t` | Days in the month, e.g. `30` |
	| `LY` | Leap year, `true` or `false` |
	| `X` | Unix timestamp in seconds |
	| `J` | Julian day number |

	Wrap literal text in square brackets to keep it from being read as tokens:
	`"[Today is] dddd"` gives `Today is Monday`.

	Defaults to the current time and the `en-us` locale.
]=]
function Time.format(format: string, currentTime: DateTimeLike, locale: string?): string
	local dateTime = Time._toDateTime(currentTime)
	local resolvedLocale = locale or DEFAULT_LOCALE

	local parts: { string } = {}
	local pending = ""

	local index = 1
	while index <= #format do
		local char = string.sub(format, index, index)
		local token = Time._matchExtendedToken(format, index)

		if char == "[" then
			-- Bracketed text is literal for FormatUniversalTime too, so hand it over whole
			local closeIndex = string.find(format, "]", index, true) or #format
			pending ..= string.sub(format, index, closeIndex)
			index = closeIndex + 1
		elseif token then
			if pending ~= "" then
				table.insert(parts, dateTime:FormatUniversalTime(pending, resolvedLocale))
				pending = ""
			end
			table.insert(parts, EXTENDED_FORMAT_TOKENS[token](dateTime, resolvedLocale))
			index += #token
		else
			pending ..= char
			index += 1
		end
	end

	if pending ~= "" then
		table.insert(parts, dateTime:FormatUniversalTime(pending, resolvedLocale))
	end

	return table.concat(parts)
end

--[=[
	Returns a `DateTime` with the second replaced. See [Time.set].
]=]
function Time.setSecond(currentTime: DateTimeLike, second: number): DateTime
	return Time.set(currentTime, "second", second)
end

--[=[
	Returns a `DateTime` with the minute replaced. See [Time.set].
]=]
function Time.setMinute(currentTime: DateTimeLike, minute: number): DateTime
	return Time.set(currentTime, "minute", minute)
end

--[=[
	Returns a `DateTime` with the 24-hour hour replaced. See [Time.set].
]=]
function Time.setHour(currentTime: DateTimeLike, hour: number): DateTime
	return Time.set(currentTime, "hour", hour)
end

--[=[
	Returns a `DateTime` with the 12-hour hour replaced, staying in the same half of the day, so
	setting 3 on a 13:45 time gives 15:45. 12 is midnight in the morning and noon in the afternoon.
]=]
function Time.setRegularHour(currentTime: DateTimeLike, hour: number): DateTime
	assert(type(hour) == "number", "Bad hour")

	local isAfternoon = Time.getHour(currentTime) >= 12
	return Time.set(currentTime, "hour", hour % 12 + (if isAfternoon then 12 else 0))
end

--[=[
	Returns a `DateTime` with the day of the year (1-366) replaced, keeping the clock. A day past
	the end of the year rolls into the next one.
]=]
function Time.setDay(currentTime: DateTimeLike, day: number): DateTime
	assert(type(day) == "number", "Bad day")

	local t = Time._toUniversalTime(currentTime)
	return Time._fromUniversalTimeOverflowing(t.Year, 1, math.floor(day), t.Hour, t.Minute, t.Second, t.Millisecond)
end

--[=[
	Returns a `DateTime` with the year replaced. See [Time.set].
]=]
function Time.setYear(currentTime: DateTimeLike, year: number): DateTime
	return Time.set(currentTime, "year", year)
end

--[=[
	Returns a `DateTime` with the month (1-12) replaced. See [Time.set].
]=]
function Time.setMonth(currentTime: DateTimeLike, month: number): DateTime
	return Time.set(currentTime, "month", month)
end

--[=[
	Returns a `DateTime` with the day of the month replaced. See [Time.set].
]=]
function Time.setDayOfTheMonth(currentTime: DateTimeLike, dayOfTheMonth: number): DateTime
	return Time.set(currentTime, "date", dayOfTheMonth)
end

--[=[
	Returns a `DateTime` with the day of the week (0-6, starting on Sunday) replaced, moving
	within the current week. See [Time.set].
]=]
function Time.setDayOfTheWeek(currentTime: DateTimeLike, dayOfTheWeek: number): DateTime
	return Time.set(currentTime, "day", dayOfTheWeek)
end

--[=[
	Returns a `DateTime` on the given Julian day number, keeping the clock.
]=]
function Time.setJulianDate(currentTime: DateTimeLike, julianDate: number): DateTime
	assert(type(julianDate) == "number", "Bad julianDate")

	local dateTime = Time._toDateTime(currentTime)
	local millisecondsIntoDay = dateTime.UnixTimestampMillis % (SECONDS_PER_DAY * 1000)
	local unixDay = math.floor(julianDate) - UNIX_EPOCH_JULIAN_DAY

	return DateTime.fromUnixTimestampMillis(unixDay * SECONDS_PER_DAY * 1000 + millisecondsIntoDay)
end

return Time
