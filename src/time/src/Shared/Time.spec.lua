--!strict
--[[
	@class Time.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Time = require("Time")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- All timestamps are UTC unix seconds.
local EPOCH = 0 -- 1970-01-01 Thursday 00:00:00
local Y2000_FEB_29 = 951782400 -- 2000-02-29 Tuesday 00:00:00, day 60
local Y2000_MAR_1 = 951868800 -- 2000-03-01 Wednesday 00:00:00, day 61
local Y2000_LAST_SECOND = 978307199 -- 2000-12-31 Sunday 23:59:59, day 366
local Y2005_JAN_1 = 1104537600 -- 2005-01-01 Saturday 00:00:00
local Y2024_JAN_1 = 1704067200 -- 2024-01-01 Monday 00:00:00
local Y2024_FEB_29 = 1709164800 -- 2024-02-29 Thursday 00:00:00, day 60
local Y2024_LAST_SECOND = 1735689599 -- 2024-12-31 Tuesday 23:59:59, day 366
local Y2025_SEP_7 = 1757203200 -- 2025-09-07 Sunday 00:00:00
local Y2025_SEP_8 = 1757289600 -- 2025-09-08 Monday 00:00:00
local Y2025_SEP_22 = 1758499200 -- 2025-09-22 Monday 00:00:00, day 265
local Y2025_SEP_22_11_59_59 = 1758542399 -- 2025-09-22 Monday 11:59:59
local Y2025_SEP_22_NOON = 1758542400 -- 2025-09-22 Monday 12:00:00
local Y2025_SEP_22_13_00 = 1758546000 -- 2025-09-22 Monday 13:00:00
local Y2025_SEP_22_LAST_SECOND = 1758585599 -- 2025-09-22 Monday 23:59:59

describe("Time.getDaysMonthTable", function()
	it("should give February 29 days in a leap year", function()
		expect(Time.getDaysMonthTable(2024)).toEqual({ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })
	end)

	it("should give February 28 days in a common year", function()
		expect(Time.getDaysMonthTable(2023)).toEqual({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })
	end)

	it("should treat centuries as common years unless divisible by 400", function()
		expect(Time.getDaysMonthTable(1900)[2]).toBe(28)
		expect(Time.getDaysMonthTable(2000)[2]).toBe(29)
		expect(Time.getDaysMonthTable(2100)[2]).toBe(28)
	end)

	it("should return a read-only table", function()
		expect(table.isfrozen(Time.getDaysMonthTable(2024))).toBe(true)
	end)
end)

describe("Time.getSecond / getMinute / getHour", function()
	it("should be zero at the epoch", function()
		expect(Time.getSecond(EPOCH)).toBe(0)
		expect(Time.getMinute(EPOCH)).toBe(0)
		expect(Time.getHour(EPOCH)).toBe(0)
	end)

	it("should extract the clock components of a time", function()
		expect(Time.getSecond(Y2025_SEP_22_LAST_SECOND)).toBe(59)
		expect(Time.getMinute(Y2025_SEP_22_LAST_SECOND)).toBe(59)
		expect(Time.getHour(Y2025_SEP_22_LAST_SECOND)).toBe(23)
	end)

	it("should report noon as hour 12", function()
		expect(Time.getHour(Y2025_SEP_22_NOON)).toBe(12)
	end)

	it("should floor fractional seconds", function()
		expect(Time.getSecond(1.9)).toBe(1)
		expect(Time.getMinute(119.9)).toBe(1)
	end)
end)

describe("Time.getDay", function()
	it("should be day 1 on January 1st", function()
		expect(Time.getDay(EPOCH)).toBe(1)
		expect(Time.getDay(Y2024_JAN_1)).toBe(1)
	end)

	it("should count February 29th as day 60", function()
		expect(Time.getDay(Y2024_FEB_29)).toBe(60)
	end)

	it("should reach day 366 at the end of a leap year", function()
		expect(Time.getDay(Y2024_LAST_SECOND)).toBe(366)
		expect(Time.getDay(Y2000_LAST_SECOND)).toBe(366)
	end)

	it("should compute the day of the year", function()
		expect(Time.getDay(Y2025_SEP_22)).toBe(265)
		expect(Time.getDay(Y2025_SEP_22_LAST_SECOND)).toBe(265)
	end)
end)

describe("Time.getYear", function()
	it("should be 1970 at the epoch", function()
		expect(Time.getYear(EPOCH)).toBe(1970)
	end)

	it("should stay in the same year until the last second", function()
		expect(Time.getYear(Y2000_LAST_SECOND)).toBe(2000)
		expect(Time.getYear(Y2024_LAST_SECOND)).toBe(2024)
	end)

	it("should roll over on January 1st", function()
		expect(Time.getYear(Y2024_JAN_1)).toBe(2024)
		expect(Time.getYear(Y2025_SEP_22)).toBe(2025)
	end)
end)

describe("Time.getYearShort", function()
	it("should return the last two digits of the year", function()
		expect(Time.getYearShort(Y2005_JAN_1)).toBe(5)
		expect(Time.getYearShort(Y2024_JAN_1)).toBe(24)
	end)

	it("should zero pad the formatted short year", function()
		expect(Time.getYearShortFormatted(Y2005_JAN_1)).toBe("05")
		expect(Time.getYearShortFormatted(Y2024_JAN_1)).toBe("24")
	end)
end)

describe("Time.getMonth", function()
	it("should be January at the epoch", function()
		expect(Time.getMonth(EPOCH)).toBe(1)
	end)

	it("should handle the leap day boundary", function()
		expect(Time.getMonth(Y2000_FEB_29)).toBe(2)
		expect(Time.getMonth(Y2000_MAR_1)).toBe(3)
		expect(Time.getMonth(Y2024_FEB_29)).toBe(2)
	end)

	it("should be December at the end of the year", function()
		expect(Time.getMonth(Y2000_LAST_SECOND)).toBe(12)
		expect(Time.getMonth(Y2024_LAST_SECOND)).toBe(12)
	end)

	it("should compute the month", function()
		expect(Time.getMonth(Y2025_SEP_22)).toBe(9)
	end)

	it("should zero pad the formatted month", function()
		expect(Time.getFormattedMonth(Y2000_FEB_29)).toBe("02")
		expect(Time.getFormattedMonth(Y2000_LAST_SECOND)).toBe("12")
	end)
end)

describe("Time.getDayOfTheMonth", function()
	it("should be the 1st at the epoch", function()
		expect(Time.getDayOfTheMonth(EPOCH)).toBe(1)
	end)

	it("should handle the leap day boundary", function()
		expect(Time.getDayOfTheMonth(Y2000_FEB_29)).toBe(29)
		expect(Time.getDayOfTheMonth(Y2000_MAR_1)).toBe(1)
	end)

	it("should be the 31st at the end of the year", function()
		expect(Time.getDayOfTheMonth(Y2000_LAST_SECOND)).toBe(31)
	end)

	it("should compute the day of the month", function()
		expect(Time.getDayOfTheMonth(Y2025_SEP_22)).toBe(22)
		expect(Time.getDayOfTheMonth(Y2025_SEP_22_LAST_SECOND)).toBe(22)
	end)

	it("should zero pad the formatted day of the month", function()
		expect(Time.getFormattedDayOfTheMonth(EPOCH)).toBe("01")
		expect(Time.getFormattedDayOfTheMonth(Y2000_FEB_29)).toBe("29")
	end)
end)

describe("Time.getMonthName", function()
	it("should return the full month name", function()
		expect(Time.getMonthName(EPOCH)).toBe("January")
		expect(Time.getMonthName(Y2000_FEB_29)).toBe("February")
		expect(Time.getMonthName(Y2025_SEP_22)).toBe("September")
		expect(Time.getMonthName(Y2000_LAST_SECOND)).toBe("December")
	end)

	it("should return the short month name", function()
		expect(Time.getMonthNameShort(EPOCH)).toBe("Jan")
		expect(Time.getMonthNameShort(Y2000_FEB_29)).toBe("Feb")
		expect(Time.getMonthNameShort(Y2025_SEP_22)).toBe("Sep")
		expect(Time.getMonthNameShort(Y2000_LAST_SECOND)).toBe("Dec")
	end)
end)

describe("Time.getJulianDate", function()
	it("should be the Julian day number of the epoch", function()
		expect(Time.getJulianDate(EPOCH)).toBe(2440588)
	end)

	it("should compute the Julian day number", function()
		expect(Time.getJulianDate(Y2024_JAN_1)).toBe(2460311)
		expect(Time.getJulianDate(Y2025_SEP_22)).toBe(2460941)
	end)

	it("should not change within a day", function()
		expect(Time.getJulianDate(Y2025_SEP_22_LAST_SECOND)).toBe(Time.getJulianDate(Y2025_SEP_22))
	end)
end)

describe("Time.getDayOfTheWeek", function()
	it("should number the week from Sunday as 0", function()
		expect(Time.getDayOfTheWeek(Y2025_SEP_7)).toBe(0)
		expect(Time.getDayOfTheWeek(Y2025_SEP_8)).toBe(1)
		expect(Time.getDayOfTheWeek(EPOCH)).toBe(4)
		expect(Time.getDayOfTheWeek(Y2005_JAN_1)).toBe(6)
	end)

	it("should return the full day name", function()
		expect(Time.getDayOfTheWeekName(Y2025_SEP_7)).toBe("Sunday")
		expect(Time.getDayOfTheWeekName(Y2025_SEP_8)).toBe("Monday")
		expect(Time.getDayOfTheWeekName(EPOCH)).toBe("Thursday")
		expect(Time.getDayOfTheWeekName(Y2005_JAN_1)).toBe("Saturday")
	end)

	it("should return the short day name", function()
		expect(Time.getDayOfTheWeekNameShort(Y2025_SEP_7)).toBe("Sun")
		expect(Time.getDayOfTheWeekNameShort(Y2025_SEP_8)).toBe("Mon")
		expect(Time.getDayOfTheWeekNameShort(EPOCH)).toBe("Thu")
		expect(Time.getDayOfTheWeekNameShort(Y2005_JAN_1)).toBe("Sat")
	end)
end)

describe("Time.getOrdinalOfNumber", function()
	it("should use st, nd, rd for 1, 2, 3", function()
		expect(Time.getOrdinalOfNumber(1)).toBe("st")
		expect(Time.getOrdinalOfNumber(2)).toBe("nd")
		expect(Time.getOrdinalOfNumber(3)).toBe("rd")
		expect(Time.getOrdinalOfNumber(4)).toBe("th")
	end)

	it("should use th for the teens", function()
		expect(Time.getOrdinalOfNumber(11)).toBe("th")
		expect(Time.getOrdinalOfNumber(12)).toBe("th")
		expect(Time.getOrdinalOfNumber(13)).toBe("th")
		expect(Time.getOrdinalOfNumber(111)).toBe("th")
		expect(Time.getOrdinalOfNumber(112)).toBe("th")
	end)

	it("should use st, nd, rd for 21, 22, 23", function()
		expect(Time.getOrdinalOfNumber(21)).toBe("st")
		expect(Time.getOrdinalOfNumber(22)).toBe("nd")
		expect(Time.getOrdinalOfNumber(23)).toBe("rd")
		expect(Time.getOrdinalOfNumber(31)).toBe("st")
		expect(Time.getOrdinalOfNumber(101)).toBe("st")
	end)

	it("should return the ordinal of the day of the month", function()
		expect(Time.getDayOfTheMonthOrdinal(EPOCH)).toBe("st")
		expect(Time.getDayOfTheMonthOrdinal(Y2025_SEP_22)).toBe("nd")
		expect(Time.getDayOfTheMonthOrdinal(Y2000_LAST_SECOND)).toBe("st")
	end)
end)

describe("Time formatted clock components", function()
	it("should zero pad seconds and minutes", function()
		expect(Time.getFormattedSecond(EPOCH)).toBe("00")
		expect(Time.getFormattedSecond(65)).toBe("05")
		expect(Time.getFormattedSecond(Y2025_SEP_22_LAST_SECOND)).toBe("59")
		expect(Time.getFormattedMinute(EPOCH)).toBe("00")
		expect(Time.getFormattedMinute(300)).toBe("05")
		expect(Time.getFormattedMinute(Y2025_SEP_22_LAST_SECOND)).toBe("59")
	end)

	it("should zero pad the 24-hour hour", function()
		expect(Time.getHourFormatted(EPOCH)).toBe("00")
		expect(Time.getHourFormatted(Y2025_SEP_22_13_00)).toBe("13")
		expect(Time.getMilitaryHour(EPOCH)).toBe("00")
		expect(Time.getMilitaryHour(Y2025_SEP_22_LAST_SECOND)).toBe("23")
	end)
end)

describe("Time.getRegularHour", function()
	it("should report midnight as 12", function()
		expect(Time.getRegularHour(EPOCH)).toBe(12)
	end)

	it("should report noon as 12", function()
		expect(Time.getRegularHour(Y2025_SEP_22_NOON)).toBe(12)
	end)

	it("should wrap the afternoon to 1-11", function()
		expect(Time.getRegularHour(Y2025_SEP_22_13_00)).toBe(1)
		expect(Time.getRegularHour(Y2025_SEP_22_LAST_SECOND)).toBe(11)
	end)

	it("should keep the morning as 1-11", function()
		expect(Time.getRegularHour(Y2025_SEP_22_11_59_59)).toBe(11)
	end)

	it("should zero pad the 12-hour hour", function()
		expect(Time.getRegularHourFormatted(Y2025_SEP_22_13_00)).toBe("01")
		expect(Time.getRegularHourFormatted(Y2025_SEP_22_NOON)).toBe("12")
	end)
end)

describe("Time.getamOrpm", function()
	it("should be am before noon", function()
		expect(Time.getamOrpm(EPOCH)).toBe("am")
		expect(Time.getamOrpm(Y2025_SEP_22_11_59_59)).toBe("am")
		expect(Time.getAMorPM(EPOCH)).toBe("AM")
		expect(Time.getAMorPM(Y2025_SEP_22_11_59_59)).toBe("AM")
	end)

	it("should be pm from noon onwards", function()
		expect(Time.getamOrpm(Y2025_SEP_22_NOON)).toBe("pm")
		expect(Time.getamOrpm(Y2025_SEP_22_LAST_SECOND)).toBe("pm")
		expect(Time.getAMorPM(Y2025_SEP_22_NOON)).toBe("PM")
		expect(Time.getAMorPM(Y2025_SEP_22_LAST_SECOND)).toBe("PM")
	end)
end)

describe("Time.isLeapYear", function()
	it("should detect leap years", function()
		expect(Time.isLeapYear(Y2000_FEB_29)).toBe(true)
		expect(Time.isLeapYear(Y2024_JAN_1)).toBe(true)
	end)

	it("should detect common years", function()
		expect(Time.isLeapYear(Y2005_JAN_1)).toBe(false)
		expect(Time.isLeapYear(Y2025_SEP_22)).toBe(false)
	end)
end)

describe("Time.getDaysInMonth", function()
	it("should return the days in the month of the given time", function()
		expect(Time.getDaysInMonth(EPOCH)).toBe(31)
		expect(Time.getDaysInMonth(Y2024_FEB_29)).toBe(29)
		expect(Time.getDaysInMonth(Y2025_SEP_22)).toBe(30)
		expect(Time.getDaysInMonth(Y2000_LAST_SECOND)).toBe(31)
	end)
end)

describe("Time.format", function()
	it("should pass Roblox tokens through to FormatUniversalTime", function()
		expect(Time.format("YYYY-MM-DD HH:mm:ss", Y2025_SEP_22_LAST_SECOND)).toBe("2025-09-22 23:59:59")
		expect(Time.format("YYYY-MM-DD HH:mm:ss", EPOCH)).toBe("1970-01-01 00:00:00")
		expect(Time.format("dddd, MMMM D YYYY", Y2025_SEP_22)).toBe("Monday, September 22 2025")
		expect(Time.format("ddd MMM D", Y2005_JAN_1)).toBe("Sat Jan 1")
		expect(Time.format("LL", Y2025_SEP_22)).toBe("September 22, 2025")
	end)

	it("should format a 12-hour clock", function()
		expect(Time.format("h:mm a", Y2025_SEP_22_13_00)).toBe("1:00 pm")
		expect(Time.format("hh:mm A", Y2025_SEP_22_NOON)).toBe("12:00 PM")
		expect(Time.format("h:mm a", EPOCH)).toBe("12:00 am")
	end)

	it("should format the short year and day of the year", function()
		expect(Time.format("YY", Y2005_JAN_1)).toBe("05")
		expect(Time.format("DDD", Y2024_LAST_SECOND)).toBe("366")
	end)

	it("should add ordinal suffixes", function()
		expect(Time.format("Do", Y2025_SEP_22)).toBe("22nd")
		expect(Time.format("Do", EPOCH)).toBe("1st")
		expect(Time.format("Do", Y2000_LAST_SECOND)).toBe("31st")
		expect(Time.format("DDDo", Y2025_SEP_22)).toBe("265th")
		expect(Time.format("MMMM Do, YYYY", Y2025_SEP_22)).toBe("September 22nd, 2025")
	end)

	it("should format days in month, leap year, unix timestamp and Julian day", function()
		expect(Time.format("t", Y2025_SEP_22)).toBe("30")
		expect(Time.format("t", Y2024_FEB_29)).toBe("29")
		expect(Time.format("LY", Y2024_FEB_29)).toBe("true")
		expect(Time.format("LY", Y2025_SEP_22)).toBe("false")
		expect(Time.format("X", Y2025_SEP_22)).toBe(tostring(Y2025_SEP_22))
		expect(Time.format("J", Y2025_SEP_22)).toBe("2460941")
	end)

	it("should mix extension tokens with Roblox tokens", function()
		expect(Time.format("dddd Do [of] MMMM (t [days])", Y2025_SEP_22)).toBe("Monday 22nd of September (30 days)")
		expect(Time.format("D/t LY", Y2024_FEB_29)).toBe("29/29 true")
	end)

	it("should leave punctuation alone", function()
		expect(Time.format("(YYYY) -- /MM/", Y2024_JAN_1)).toBe("(2024) -- /01/")
		expect(Time.format("", Y2024_JAN_1)).toBe("")
	end)

	it("should treat bracketed text as literal", function()
		expect(Time.format("[YYYY] YYYY", Y2024_JAN_1)).toBe("YYYY 2024")
		expect(Time.format("[Do] Do", Y2025_SEP_22)).toBe("Do 22nd")
		expect(Time.format("[Today is] dddd", Y2025_SEP_22)).toBe("Today is Monday")
	end)

	it("should default to the current time", function()
		local expected = os.date("!%Y", os.time())

		expect(Time.format("YYYY")).toBe(expected)
	end)
end)

describe("Time with a locale", function()
	it("should default to en-us", function()
		expect(Time.getMonthName(Y2025_SEP_22)).toBe(Time.getMonthName(Y2025_SEP_22, "en-us"))
		expect(Time.getDayOfTheMonthOrdinal(Y2025_SEP_22)).toBe(Time.getDayOfTheMonthOrdinal(Y2025_SEP_22, "en-us"))
	end)

	it("should localize ordinals", function()
		expect(Time.getOrdinalOfNumber(22, "fr-fr")).toBe("e")
		expect(Time.getOrdinalOfNumber(1, "fr-fr")).toBe("er")
		expect(Time.getDayOfTheMonthOrdinal(Y2025_SEP_22, "de-de")).toBe(".")
		expect(Time.format("Do", Y2025_SEP_22, "de-de")).toBe("22.")
		expect(Time.format("Do", Y2025_SEP_22, "zh-cn")).toBe("第22")
	end)

	it("should localize names", function()
		expect(Time.getMonthName(Y2025_SEP_22, "fr-fr")).toBe("septembre")
		expect(Time.getDayOfTheWeekName(Y2025_SEP_22, "fr-fr")).toBe("lundi")
		expect(Time.getMonthName(Y2025_SEP_22, "de-de")).toBe("September")
		expect(Time.getDayOfTheWeekName(Y2025_SEP_22, "de-de")).toBe("Montag")
	end)

	it("should localize format output while keeping extension tokens", function()
		expect(Time.format("dddd Do MMMM YYYY", Y2025_SEP_22, "fr-fr")).toBe("lundi 22e septembre 2025")
		expect(Time.format("LL", Y2025_SEP_22, "en-gb")).toBe("22 September 2025")
	end)

	it("should keep padded numbers stable across locales", function()
		expect(Time.getFormattedMonth(Y2025_SEP_22, "fr-fr")).toBe("09")
		expect(Time.getHourFormatted(Y2025_SEP_22_13_00, "fr-fr")).toBe("13")
		expect(Time.getFormattedSecond(Y2025_SEP_22_LAST_SECOND, "de-de")).toBe("59")
	end)
end)

describe("Time with DateTime inputs", function()
	it("should accept a DateTime anywhere a timestamp is accepted", function()
		local dateTime = DateTime.fromUnixTimestamp(Y2025_SEP_22_13_00)

		expect(Time.getYear(dateTime)).toBe(2025)
		expect(Time.getMonth(dateTime)).toBe(9)
		expect(Time.getDayOfTheMonth(dateTime)).toBe(22)
		expect(Time.getHour(dateTime)).toBe(13)
		expect(Time.getDayOfTheWeekName(dateTime)).toBe("Monday")
		expect(Time.format("YYYY-MM-DD h:mm a", dateTime)).toBe("2025-09-22 1:00 pm")
	end)

	it("should agree between a DateTime and its timestamp", function()
		local dateTime = DateTime.fromUnixTimestamp(Y2000_LAST_SECOND)

		expect(Time.format("dddd, MMMM Do YYYY HH:mm:ss", dateTime)).toBe(
			Time.format("dddd, MMMM Do YYYY HH:mm:ss", Y2000_LAST_SECOND)
		)
	end)

	it("should accept an ISO 8601 string", function()
		expect(Time.getUnixTimestamp("2025-09-22T13:00:00Z")).toBe(Y2025_SEP_22_13_00)
		expect(Time.format("YYYY-MM-DD HH:mm", "2025-09-22T13:00:00Z")).toBe("2025-09-22 13:00")
		expect(Time.getDayOfTheWeekName("2000-12-31T23:59:59Z")).toBe("Sunday")
	end)

	it("should reject a string that is not an ISO date", function()
		expect(function()
			Time.getYear("yesterday")
		end).toThrow("Bad ISO date")
	end)

	it("should use the current time for nil", function()
		local now = DateTime.now()

		expect(Time.getYear(nil)).toBe(Time.getYear(now))
		expect(math.abs(Time.getUnixTimestamp(nil) - now.UnixTimestamp) <= 1).toBe(true)
	end)

	it("should return the unix timestamp", function()
		expect(Time.getUnixTimestamp(Y2025_SEP_22)).toBe(Y2025_SEP_22)
		expect(Time.getUnixTimestamp(DateTime.fromUnixTimestamp(Y2025_SEP_22))).toBe(Y2025_SEP_22)
		expect(Time.getUnixTimestamp(Y2025_SEP_22 + 0.75)).toBe(Y2025_SEP_22)
	end)
end)

describe("Time.add", function()
	local function iso(dateTime: DateTime): string
		return dateTime:ToIsoDate()
	end

	it("should add fixed units", function()
		expect(iso(Time.add(Y2025_SEP_22, 10, "day"))).toBe("2025-10-02T00:00:00Z")
		expect(iso(Time.add(Y2025_SEP_22, 2, "week"))).toBe("2025-10-06T00:00:00Z")
		expect(iso(Time.add(Y2025_SEP_22, 25, "hour"))).toBe("2025-09-23T01:00:00Z")
		expect(iso(Time.add(Y2025_SEP_22, 90, "minute"))).toBe("2025-09-22T01:30:00Z")
		expect(iso(Time.add(Y2025_SEP_22, 1.5, "second"))).toBe("2025-09-22T00:00:01Z")
		expect(Time.add(Y2025_SEP_22, 250, "millisecond").UnixTimestampMillis).toBe(Y2025_SEP_22 * 1000 + 250)
	end)

	it("should move months on the calendar and clamp the day", function()
		expect(iso(Time.add("2025-01-31T12:30:00Z", 1, "month"))).toBe("2025-02-28T12:30:00Z")
		expect(iso(Time.add("2024-01-31T00:00:00Z", 1, "month"))).toBe("2024-02-29T00:00:00Z")
		expect(iso(Time.add("2025-12-15T00:00:00Z", 1, "month"))).toBe("2026-01-15T00:00:00Z")
		expect(iso(Time.add("2025-01-15T00:00:00Z", -1, "month"))).toBe("2024-12-15T00:00:00Z")
		expect(iso(Time.add("2025-03-31T00:00:00Z", -1, "month"))).toBe("2025-02-28T00:00:00Z")
		expect(iso(Time.add(Y2025_SEP_22, 14, "month"))).toBe("2026-11-22T00:00:00Z")
	end)

	it("should move quarters and years on the calendar", function()
		expect(iso(Time.add(Y2025_SEP_22, 1, "quarter"))).toBe("2025-12-22T00:00:00Z")
		expect(iso(Time.add("2024-02-29T00:00:00Z", 1, "year"))).toBe("2025-02-28T00:00:00Z")
		expect(iso(Time.add("2024-02-29T00:00:00Z", 4, "years"))).toBe("2028-02-29T00:00:00Z")
	end)

	it("should accept plural and short units", function()
		expect(iso(Time.add(Y2025_SEP_22, 1, "days"))).toBe(iso(Time.add(Y2025_SEP_22, 1, "d")))
		expect(iso(Time.add(Y2025_SEP_22, 1, "M"))).toBe(iso(Time.add(Y2025_SEP_22, 1, "month")))
		expect(iso(Time.add(Y2025_SEP_22, 1, "m"))).toBe(iso(Time.add(Y2025_SEP_22, 1, "minute")))
		expect(iso(Time.add(Y2025_SEP_22, 1, "y"))).toBe(iso(Time.add(Y2025_SEP_22, 1, "year")))
		expect(iso(Time.add(Y2025_SEP_22, 1, "Q"))).toBe(iso(Time.add(Y2025_SEP_22, 3, "months")))
	end)

	it("should reject unknown units", function()
		expect(function()
			Time.add(Y2025_SEP_22, 1, "fortnight" :: any)
		end).toThrow("Bad unit")
	end)

	it("should return a DateTime usable everywhere else", function()
		expect(Time.format("dddd Do MMMM", Time.add(Y2025_SEP_22, 1, "day"))).toBe("Tuesday 23rd September")
		expect(Time.getDayOfTheWeekName(Time.add(nil, 0, "day"))).toBe(Time.getDayOfTheWeekName(nil))
	end)
end)

describe("Time.subtract", function()
	it("should be add with a negated value", function()
		expect(Time.subtract(Y2025_SEP_22, 1, "day"):ToIsoDate()).toBe("2025-09-21T00:00:00Z")
		expect(Time.subtract("2025-03-31T00:00:00Z", 1, "month"):ToIsoDate()).toBe("2025-02-28T00:00:00Z")
		expect(Time.subtract(Y2025_SEP_22, -1, "hour"):ToIsoDate()).toBe("2025-09-22T01:00:00Z")
	end)
end)

describe("Time.startOf / endOf", function()
	local SAMPLE = DateTime.fromUnixTimestampMillis(1758548730250) -- 2025-09-22T13:45:30.250Z, a Monday

	local function iso(dateTime: DateTime): string
		return dateTime:ToIsoDate()
	end

	it("should snap to the start of clock units", function()
		expect(Time.startOf(SAMPLE, "millisecond").UnixTimestampMillis).toBe(SAMPLE.UnixTimestampMillis)
		expect(Time.startOf(SAMPLE, "second").UnixTimestampMillis).toBe(1758548730000)
		expect(iso(Time.startOf(SAMPLE, "minute"))).toBe("2025-09-22T13:45:00Z")
		expect(iso(Time.startOf(SAMPLE, "hour"))).toBe("2025-09-22T13:00:00Z")
		expect(iso(Time.startOf(SAMPLE, "day"))).toBe("2025-09-22T00:00:00Z")
		expect(iso(Time.startOf(SAMPLE, "date"))).toBe("2025-09-22T00:00:00Z")
	end)

	it("should snap to the start of calendar units", function()
		expect(iso(Time.startOf(SAMPLE, "week"))).toBe("2025-09-21T00:00:00Z")
		expect(iso(Time.startOf("2025-09-21T12:00:00Z", "week"))).toBe("2025-09-21T00:00:00Z")
		expect(iso(Time.startOf("2025-09-27T12:00:00Z", "week"))).toBe("2025-09-21T00:00:00Z")
		expect(iso(Time.startOf(SAMPLE, "month"))).toBe("2025-09-01T00:00:00Z")
		expect(iso(Time.startOf(SAMPLE, "quarter"))).toBe("2025-07-01T00:00:00Z")
		expect(iso(Time.startOf("2025-12-31T23:59:59Z", "quarter"))).toBe("2025-10-01T00:00:00Z")
		expect(iso(Time.startOf(SAMPLE, "year"))).toBe("2025-01-01T00:00:00Z")
	end)

	it("should end one millisecond before the next unit starts", function()
		expect(Time.endOf(SAMPLE, "second").UnixTimestampMillis).toBe(1758548730999)
		expect(Time.endOf(SAMPLE, "day").UnixTimestampMillis).toBe(
			Time.startOf("2025-09-23T00:00:00Z", "day").UnixTimestampMillis - 1
		)
		expect(iso(Time.endOf(SAMPLE, "day"))).toBe("2025-09-22T23:59:59Z")
		expect(iso(Time.endOf(SAMPLE, "week"))).toBe("2025-09-27T23:59:59Z")
		expect(iso(Time.endOf(SAMPLE, "month"))).toBe("2025-09-30T23:59:59Z")
		expect(iso(Time.endOf("2024-02-10T00:00:00Z", "month"))).toBe("2024-02-29T23:59:59Z")
		expect(iso(Time.endOf(SAMPLE, "quarter"))).toBe("2025-09-30T23:59:59Z")
		expect(iso(Time.endOf(SAMPLE, "year"))).toBe("2025-12-31T23:59:59Z")
	end)

	it("should accept short units and any DateTimeLike", function()
		expect(iso(Time.startOf(Y2025_SEP_22_13_00, "M"))).toBe("2025-09-01T00:00:00Z")
		expect(iso(Time.endOf("2025-09-22T13:00:00Z", "y"))).toBe("2025-12-31T23:59:59Z")
		expect(Time.getHour(Time.startOf(nil, "day"))).toBe(0)
	end)
end)

describe("Time.get", function()
	local SAMPLE = DateTime.fromUnixTimestampMillis(1758548730250) -- 2025-09-22T13:45:30.250Z, a Monday

	it("should read every field", function()
		expect(Time.get(SAMPLE, "year")).toBe(2025)
		expect(Time.get(SAMPLE, "month")).toBe(9)
		expect(Time.get(SAMPLE, "date")).toBe(22)
		expect(Time.get(SAMPLE, "day")).toBe(1)
		expect(Time.get(SAMPLE, "hour")).toBe(13)
		expect(Time.get(SAMPLE, "minute")).toBe(45)
		expect(Time.get(SAMPLE, "second")).toBe(30)
		expect(Time.get(SAMPLE, "millisecond")).toBe(250)
	end)

	it("should accept plural and short fields", function()
		expect(Time.get(SAMPLE, "y")).toBe(2025)
		expect(Time.get(SAMPLE, "M")).toBe(9)
		expect(Time.get(SAMPLE, "D")).toBe(22)
		expect(Time.get(SAMPLE, "d")).toBe(1)
		expect(Time.get(SAMPLE, "h")).toBe(13)
		expect(Time.get(SAMPLE, "m")).toBe(45)
		expect(Time.get(SAMPLE, "s")).toBe(30)
		expect(Time.get(SAMPLE, "ms")).toBe(250)
		expect(Time.get(SAMPLE, "hours")).toBe(13)
	end)

	it("should accept any DateTimeLike", function()
		expect(Time.get("2000-12-31T23:59:59Z", "day")).toBe(0)
		expect(Time.get(Y2025_SEP_22_13_00, "hour")).toBe(13)
	end)

	it("should reject unknown fields", function()
		expect(function()
			Time.get(SAMPLE, "week" :: any)
		end).toThrow("Bad field")
	end)
end)

describe("Time.set", function()
	local SAMPLE = "2025-09-22T13:45:30Z" -- a Monday

	local function iso(dateTime: DateTime): string
		return dateTime:ToIsoDate()
	end

	it("should replace calendar fields", function()
		expect(iso(Time.set(SAMPLE, "year", 2030))).toBe("2030-09-22T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "month", 12))).toBe("2025-12-22T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "date", 1))).toBe("2025-09-01T13:45:30Z")
	end)

	it("should roll calendar fields over like JavaScript dates", function()
		expect(iso(Time.set(SAMPLE, "month", 13))).toBe("2026-01-22T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "month", 0))).toBe("2024-12-22T13:45:30Z")
		expect(iso(Time.set("2025-01-31T00:00:00Z", "month", 2))).toBe("2025-03-03T00:00:00Z")
		expect(iso(Time.set("2024-02-29T00:00:00Z", "year", 2025))).toBe("2025-03-01T00:00:00Z")
		expect(iso(Time.set(SAMPLE, "date", 31))).toBe("2025-10-01T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "date", 0))).toBe("2025-08-31T13:45:30Z")
	end)

	it("should move within the week when setting the day", function()
		expect(iso(Time.set(SAMPLE, "day", 0))).toBe("2025-09-21T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "day", 1))).toBe("2025-09-22T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "day", 6))).toBe("2025-09-27T13:45:30Z")
		expect(iso(Time.set(SAMPLE, "day", 8))).toBe("2025-09-29T13:45:30Z")
	end)

	it("should replace and roll clock fields", function()
		expect(iso(Time.set(SAMPLE, "hour", 0))).toBe("2025-09-22T00:45:30Z")
		expect(iso(Time.set(SAMPLE, "hour", 25))).toBe("2025-09-23T01:45:30Z")
		expect(iso(Time.set(SAMPLE, "minute", 0))).toBe("2025-09-22T13:00:30Z")
		expect(iso(Time.set(SAMPLE, "second", 90))).toBe("2025-09-22T13:46:30Z")
		expect(Time.set(SAMPLE, "millisecond", 250).UnixTimestampMillis).toBe(1758548730250)
	end)

	it("should round trip through get", function()
		for _, field in { "year", "month", "date", "day", "hour", "minute", "second", "millisecond" } do
			local value = Time.get(SAMPLE, field :: Time.TimeField)
			expect(Time.get(Time.set(SAMPLE, field :: Time.TimeField, value), field :: Time.TimeField)).toBe(value)
		end

		expect(Time.get(Time.set(SAMPLE, "h", 7), "hour")).toBe(7)
	end)
end)

describe("Time setters", function()
	local SAMPLE = "2025-09-22T13:45:30Z" -- a Monday, day 265

	local function iso(dateTime: DateTime): string
		return dateTime:ToIsoDate()
	end

	it("should mirror the clock getters", function()
		expect(iso(Time.setSecond(SAMPLE, 5))).toBe("2025-09-22T13:45:05Z")
		expect(iso(Time.setMinute(SAMPLE, 5))).toBe("2025-09-22T13:05:30Z")
		expect(iso(Time.setHour(SAMPLE, 5))).toBe("2025-09-22T05:45:30Z")
		expect(Time.getSecond(Time.setSecond(SAMPLE, 5))).toBe(5)
		expect(Time.getMinute(Time.setMinute(SAMPLE, 5))).toBe(5)
		expect(Time.getHour(Time.setHour(SAMPLE, 5))).toBe(5)
	end)

	it("should keep the half of the day when setting the 12-hour hour", function()
		expect(iso(Time.setRegularHour(SAMPLE, 3))).toBe("2025-09-22T15:45:30Z")
		expect(iso(Time.setRegularHour(SAMPLE, 12))).toBe("2025-09-22T12:45:30Z")
		expect(iso(Time.setRegularHour("2025-09-22T01:00:00Z", 3))).toBe("2025-09-22T03:00:00Z")
		expect(iso(Time.setRegularHour("2025-09-22T01:00:00Z", 12))).toBe("2025-09-22T00:00:00Z")
		expect(Time.getRegularHour(Time.setRegularHour(SAMPLE, 3))).toBe(3)
	end)

	it("should mirror the calendar getters", function()
		expect(iso(Time.setYear(SAMPLE, 2030))).toBe("2030-09-22T13:45:30Z")
		expect(iso(Time.setMonth(SAMPLE, 2))).toBe("2025-02-22T13:45:30Z")
		expect(iso(Time.setDayOfTheMonth(SAMPLE, 30))).toBe("2025-09-30T13:45:30Z")
		expect(iso(Time.setDayOfTheWeek(SAMPLE, 5))).toBe("2025-09-26T13:45:30Z")
		expect(Time.getYear(Time.setYear(SAMPLE, 2030))).toBe(2030)
		expect(Time.getMonth(Time.setMonth(SAMPLE, 2))).toBe(2)
		expect(Time.getDayOfTheMonth(Time.setDayOfTheMonth(SAMPLE, 30))).toBe(30)
		expect(Time.getDayOfTheWeek(Time.setDayOfTheWeek(SAMPLE, 5))).toBe(5)
	end)

	it("should set the day of the year and keep the clock", function()
		expect(iso(Time.setDay(SAMPLE, 1))).toBe("2025-01-01T13:45:30Z")
		expect(iso(Time.setDay(SAMPLE, 60))).toBe("2025-03-01T13:45:30Z")
		expect(iso(Time.setDay("2024-09-22T13:45:30Z", 60))).toBe("2024-02-29T13:45:30Z")
		expect(iso(Time.setDay(SAMPLE, 366))).toBe("2026-01-01T13:45:30Z")
		expect(Time.getDay(Time.setDay(SAMPLE, 265))).toBe(265)
	end)

	it("should set the Julian day and keep the clock", function()
		expect(iso(Time.setJulianDate(SAMPLE, 2440588))).toBe("1970-01-01T13:45:30Z")
		expect(iso(Time.setJulianDate(SAMPLE, 2460941))).toBe("2025-09-22T13:45:30Z")
		expect(Time.getJulianDate(Time.setJulianDate(SAMPLE, 2460311))).toBe(2460311)
	end)
end)
