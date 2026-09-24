--!strict
--[=[
	Calendar time: describes a time relative to a
	reference day with phrases like `Today at 2:30 PM`, `Tomorrow at 9:00 AM`, `Last Friday at
	5:00 PM`, and falls back to a plain date outside of a week either way.

	```lua
	TimeCalendarUtils.calendar("2025-09-23T18:30:00Z", "2025-09-22T13:00:00Z") --> Tomorrow at 6:30 PM
	TimeCalendarUtils.calendar(os.time() - 3 * 86400) --> Last Friday at 1:00 PM (for example)
	```

	@class TimeCalendarUtils
]=]

local require = require(script.Parent.loader).load(script)

local Time = require("Time")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local TimeCalendarUtils = {}

--[=[
	See [TimeLocalizationUtils.CalendarFormat].

	@type CalendarFormat TimeLocalizationUtils.CalendarFormat
	@within TimeCalendarUtils
]=]
export type CalendarFormat = TimeLocalizationUtils.CalendarFormat

--[=[
	Which phrase to use for each distance from the reference day. Missing keys fall back to the
	locale's defaults from [TimeLocalizationUtils.getCalendarFormatsForLocale].

	@type CalendarFormats TimeLocalizationUtils.CalendarFormatOverrides
	@within TimeCalendarUtils
]=]
export type CalendarFormats = TimeLocalizationUtils.CalendarFormatOverrides

type CalendarFormatKey = "sameDay" | "nextDay" | "nextWeek" | "lastDay" | "lastWeek" | "sameElse"

local MILLISECONDS_A_DAY = 86400000

-- The distance in days from the start of the reference day picks the phrase
function TimeCalendarUtils._getFormatKey(daysFromReferenceStart: number): CalendarFormatKey
	if daysFromReferenceStart < -6 then
		return "sameElse"
	elseif daysFromReferenceStart < -1 then
		return "lastWeek"
	elseif daysFromReferenceStart < 0 then
		return "lastDay"
	elseif daysFromReferenceStart < 1 then
		return "sameDay"
	elseif daysFromReferenceStart < 2 then
		return "nextDay"
	elseif daysFromReferenceStart < 7 then
		return "nextWeek"
	else
		return "sameElse"
	end
end

--[=[
	Describes `currentTime` relative to the day of `referenceTime` (now when nil). Times within the same day, the next day, the previous day, the next six days and
	the previous six days each get their own phrase; anything further is a plain date.

	`formats` overrides any of the phrases, see [CalendarFormats]. The `locale` picks the
	default phrases through [TimeLocalizationUtils] and applies to every template.
]=]
function TimeCalendarUtils.calendar(
	currentTime: Time.DateTimeLike,
	referenceTime: Time.DateTimeLike,
	formats: CalendarFormats?,
	locale: string?
): string
	local dateTime = Time._toDateTime(currentTime)
	local reference = Time._toDateTime(referenceTime)
	local referenceStartOfDay = Time.startOf(reference, "day")

	local daysFromReferenceStart = (dateTime.UnixTimestampMillis - referenceStartOfDay.UnixTimestampMillis)
		/ MILLISECONDS_A_DAY
	local key = TimeCalendarUtils._getFormatKey(daysFromReferenceStart)

	local localeFormats: any = TimeLocalizationUtils.getCalendarFormatsForLocale(locale)
	local format: CalendarFormat = (if formats then (formats :: any)[key] else nil) or localeFormats[key]
	if type(format) == "function" then
		return format(dateTime, reference)
	end

	return Time.format(format, dateTime, locale)
end

return TimeCalendarUtils
