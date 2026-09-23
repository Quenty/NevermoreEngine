--!strict
--[[
	@class TimeDurationUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RelativeTimeUtils = require("RelativeTimeUtils")
local TimeDurationUtils = require("TimeDurationUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local SECOND = 1
local MINUTE = 60 * SECOND
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR

describe("TimeDurationUtils.toSeconds", function()
	it("should treat a bare number as seconds", function()
		expect(TimeDurationUtils.toSeconds(1.5)).toBe(1.5)
		expect(TimeDurationUtils.toMilliseconds(1.5)).toBe(1500)
		expect(TimeDurationUtils.toMilliseconds(5, "minutes")).toBe(300000)
	end)

	it("should scale a number by a unit", function()
		expect(TimeDurationUtils.toSeconds(5, "minutes")).toBe(5 * MINUTE)
		expect(TimeDurationUtils.toSeconds(2, "h")).toBe(2 * HOUR)
		expect(TimeDurationUtils.toSeconds(1, "week")).toBe(7 * DAY)
		expect(TimeDurationUtils.toSeconds(1, "month")).toBe(30 * DAY)
		expect(TimeDurationUtils.toSeconds(1, "year")).toBe(365 * DAY)
		expect(TimeDurationUtils.toSeconds(1, "quarter")).toBe(90 * DAY)
	end)

	it("should sum a duration table", function()
		expect(TimeDurationUtils.toSeconds({ hours = 1, minutes = 30 })).toBe(90 * MINUTE)
		expect(TimeDurationUtils.toSeconds({ weeks = 1, days = 1 })).toBe(8 * DAY)
		expect(TimeDurationUtils.toSeconds({ second = 2, millisecond = 5 })).toBe(2.005)
		expect(TimeDurationUtils.toSeconds({})).toBe(0)
	end)

	it("should parse ISO 8601 durations", function()
		expect(TimeDurationUtils.toSeconds("PT1H30M")).toBe(90 * MINUTE)
		expect(TimeDurationUtils.toSeconds("P1DT12H")).toBe(36 * HOUR)
		expect(TimeDurationUtils.toSeconds("P1W")).toBe(7 * DAY)
		expect(TimeDurationUtils.toSeconds("P1Y2M3DT4H5M6S")).toBe(
			365 * DAY + 60 * DAY + 3 * DAY + 4 * HOUR + 5 * MINUTE + 6 * SECOND
		)
		expect(TimeDurationUtils.toSeconds("PT1.5S")).toBe(1.5)
		expect(TimeDurationUtils.toSeconds("PT0,5S")).toBe(0.5)
		expect(TimeDurationUtils.toSeconds("-PT5S")).toBe(-5 * SECOND)
		expect(TimeDurationUtils.toSeconds("P0D")).toBe(0)
	end)

	it("should reject malformed input", function()
		expect(function()
			TimeDurationUtils.toSeconds("1H")
		end).toThrow("Bad ISO 8601 duration")
		expect(function()
			TimeDurationUtils.toSeconds("PT1X")
		end).toThrow("Bad ISO 8601 duration")
		expect(function()
			TimeDurationUtils.toSeconds({ fortnights = 1 } :: any)
		end).toThrow("Bad unit")
		expect(function()
			TimeDurationUtils.toSeconds("PT1H", "minutes")
		end).toThrow("cannot be given")
	end)
end)

describe("TimeDurationUtils.as", function()
	it("should convert to a fractional amount of a unit", function()
		expect(TimeDurationUtils.as(90 * SECOND, "minutes")).toBe(1.5)
		expect(TimeDurationUtils.as({ days = 1 }, "hours")).toBe(24)
		expect(TimeDurationUtils.as({ days = 14 }, "weeks")).toBe(2)
		expect(TimeDurationUtils.as("PT36H", "days")).toBe(1.5)
		expect(TimeDurationUtils.as({ years = 1 }, "days")).toBe(365)
	end)
end)

describe("TimeDurationUtils.toTable / get", function()
	it("should break a duration into whole units", function()
		expect(TimeDurationUtils.toTable({ hours = 1, minutes = 30 })).toEqual({
			years = 0,
			months = 0,
			days = 0,
			hours = 1,
			minutes = 30,
			seconds = 0,
			milliseconds = 0,
		})
		expect(TimeDurationUtils.toTable(400 * DAY + 90 * MINUTE + 1.25)).toEqual({
			years = 1,
			months = 1,
			days = 5,
			hours = 1,
			minutes = 30,
			seconds = 1,
			milliseconds = 250,
		})
	end)

	it("should read whole units", function()
		expect(TimeDurationUtils.get({ hours = 25 }, "hours")).toBe(1)
		expect(TimeDurationUtils.get({ hours = 25 }, "days")).toBe(1)
		expect(TimeDurationUtils.get(90 * SECOND, "seconds")).toBe(30)
		expect(TimeDurationUtils.get(90 * SECOND, "minutes")).toBe(1)
		expect(TimeDurationUtils.get({ days = 15 }, "weeks")).toBe(2)
		expect(TimeDurationUtils.get({ days = 15 }, "d")).toBe(15)
		expect(TimeDurationUtils.get({ months = 7 }, "quarters")).toBe(2)
		expect(TimeDurationUtils.get(1.25, "ms")).toBe(250)
	end)

	it("should break negative durations into negative parts", function()
		expect(TimeDurationUtils.get(-90 * SECOND, "minutes")).toBe(-1)
		expect(TimeDurationUtils.get(-90 * SECOND, "seconds")).toBe(-30)
	end)
end)

describe("TimeDurationUtils.add / subtract", function()
	it("should combine durations in milliseconds", function()
		expect(TimeDurationUtils.add(MINUTE, { seconds = 30 })).toBe(90 * SECOND)
		expect(TimeDurationUtils.add(MINUTE, 5, "seconds")).toBe(65 * SECOND)
		expect(TimeDurationUtils.subtract({ hours = 1 }, "PT15M")).toBe(45 * MINUTE)
	end)
end)

describe("TimeDurationUtils.format", function()
	it("should let the largest token absorb the overflow", function()
		expect(TimeDurationUtils.format(47 * HOUR, "h:mm:ss")).toBe("47:00:00")
		expect(TimeDurationUtils.format({ days = 45 }, "d __")).toBe("45 days")
		expect(TimeDurationUtils.format(HOUR, "m:ss")).toBe("60:00")
		expect(TimeDurationUtils.format(MINUTE, "s")).toBe("60")
		expect(TimeDurationUtils.format({ minutes = 90 }, "hh:mm:ss")).toBe("01:30:00")
		expect(TimeDurationUtils.format({ days = 10 }, "w __ d __")).toBe("1 week 3 days")
	end)

	it("should pad repeated letters and leave single ones bare", function()
		expect(TimeDurationUtils.format(HOUR + MINUTE + SECOND, "hh:mm:ss")).toBe("01:01:01")
		expect(TimeDurationUtils.format(HOUR + MINUTE + SECOND, "h:m:s")).toBe("1:1:1")
		expect(TimeDurationUtils.format({ days = 12, months = 3 }, "M/dd")).toBe("3/12")
		expect(TimeDurationUtils.format({ years = 12 }, "yy yyyy")).toBe("12 0012")
		expect(TimeDurationUtils.format(1.25, "s.SSS")).toBe("1.250")
		expect(TimeDurationUtils.format(0.25, "S __")).toBe("250 milliseconds")
		expect(TimeDurationUtils.format(0.001, "S__")).toBe("1 millisecond")
	end)

	it("should treat bracketed text as literal and leave other characters alone", function()
		expect(TimeDurationUtils.format(HOUR + MINUTE + SECOND, "h [hours] m [minutes] s [seconds]")).toBe(
			"1 hours 1 minutes 1 seconds"
		)
		expect(TimeDurationUtils.format(90 * MINUTE, "mm:ss (hh)")).toBe("30:00 (01)")
		expect(TimeDurationUtils.format(5, "[s] s [s]")).toBe("s 5 s")
	end)

	it("should drop leading zero tokens by default", function()
		expect(TimeDurationUtils.format(123 * MINUTE, "d __ h:mm:ss")).toBe("2:03:00")
		expect(TimeDurationUtils.format(45, "h:mm:ss")).toBe("45")
		expect(TimeDurationUtils.format(5 * MINUTE, "h:mm:ss")).toBe("5:00")
		expect(TimeDurationUtils.format(0, "h:mm:ss")).toBe("0")
		expect(TimeDurationUtils.format(45, "h:mm:ss", { trim = false })).toBe("0:00:45")
		expect(TimeDurationUtils.format(5 * MINUTE, "h:mm:ss", { forceLength = true })).toBe("05:00")
	end)

	it("should drop trailing, interior or all zero tokens when asked", function()
		expect(TimeDurationUtils.format({ days = 2 }, "d __ h __ m __", { trim = "both" })).toBe("2 days")
		expect(TimeDurationUtils.format({ hours = 2 }, "d __ h __ m __", { trim = "both" })).toBe("2 hours")
		expect(TimeDurationUtils.format({ hours = 2 }, "d __ h __ m __", { trim = "small" })).toBe("0 days 2 hours")
		expect(TimeDurationUtils.format({ years = 1, days = 3 }, "y __, M __, d __", { trim = "mid" })).toBe(
			"1 year, 3 days"
		)
		expect(TimeDurationUtils.format({ years = 1, days = 3 }, "y __, M __, d __, h __", { trim = "all" })).toBe(
			"1 year, 3 days"
		)
		expect(TimeDurationUtils.format(0, "d __ h __ m __", { trim = "all" })).toBe("0 minutes")
	end)

	it("should drop the text next to a dropped token", function()
		expect(TimeDurationUtils.format(45, "[in] h:mm:ss")).toBe("in 45")
		expect(TimeDurationUtils.format({ hours = 2 }, "h:mm [left]", { trim = "both" })).toBe("2 left")
		expect(TimeDurationUtils.format({ days = 2 }, "d [days] h:mm:ss", { trim = "both" })).toBe("2")
	end)

	it("should keep pinned tokens", function()
		expect(TimeDurationUtils.format(45, "h:mm:ss", { stopTrim = "m" })).toBe("0:45")
		expect(TimeDurationUtils.format(45, "h:*mm:ss")).toBe("0:45")
		expect(TimeDurationUtils.format(45, "*h:mm:ss")).toBe("0:00:45")
	end)

	it("should round the smallest token unless truncating", function()
		expect(TimeDurationUtils.format(59.6, "m:ss")).toBe("1:00")
		expect(TimeDurationUtils.format(59.6, "m:ss", { trunc = true })).toBe("59")
		expect(TimeDurationUtils.format(90, "m")).toBe("2")
		expect(TimeDurationUtils.format(90, "m", { trunc = true })).toBe("1")
		expect(TimeDurationUtils.format(29, "m")).toBe("0")
		expect(TimeDurationUtils.format(0.3, "SSS")).toBe("300")
	end)

	it("should print decimals on the smallest token with precision", function()
		expect(TimeDurationUtils.format(90, "m", { precision = 1 })).toBe("1.5")
		expect(TimeDurationUtils.format({ hours = 1, minutes = 30 }, "h", { precision = 2 })).toBe("1.50")
		expect(TimeDurationUtils.format(1234, "s", { precision = -2 })).toBe("1200")
		expect(TimeDurationUtils.format(90, "m __", { precision = 1 })).toBe("1.5 minutes")
		expect(TimeDurationUtils.format(3700, "m:ss", { precision = -2 })).toBe("61:40")
	end)

	it("should keep only the largest tokens when asked", function()
		expect(TimeDurationUtils.format({ days = 1, minutes = 5 }, "d __, h __, m __, s __", { largest = 2 })).toBe(
			"1 day, 5 minutes"
		)
		expect(TimeDurationUtils.format({ days = 1, hours = 2, minutes = 5 }, "d __, h __, m __", { largest = 2 })).toBe(
			"1 day, 2 hours"
		)
		expect(TimeDurationUtils.format({ days = 1, hours = 2 }, "d __, h __, m __", { largest = 1 })).toBe("1 day")
	end)

	it("should let a token count up to its limit before using the next", function()
		local limits: { [string]: number } = { minutes = 60 }
		expect(TimeDurationUtils.format(HOUR, "h:mm:ss", { limits = limits })).toBe("60:00")
		expect(TimeDurationUtils.format(HOUR + 59, "h:mm:ss", { limits = limits })).toBe("60:59")
		expect(TimeDurationUtils.format(HOUR + MINUTE, "h:mm:ss", { limits = limits })).toBe("1:01:00")
		expect(TimeDurationUtils.format(HOUR, "*h:mm:ss", { limits = limits })).toBe("1:00:00")
		expect(TimeDurationUtils.format(47 * HOUR, "d __ h:mm:ss", { limits = { hours = 47 } })).toBe("47:00:00")
		expect(TimeDurationUtils.format(2 * DAY - 1, "d __ h:mm:ss", { limits = { hours = 47 } })).toBe("47:59:59")
		expect(TimeDurationUtils.format(2 * DAY, "d __ h:mm:ss", { limits = { hours = 47 } })).toBe("2 days 0:00:00")
		expect(TimeDurationUtils.format({ days = 1, hours = 1 }, "d __ h __ m __", {
			limits = { hours = 47, minutes = 1500 },
		})).toBe("1500 minutes")
	end)

	it("should clamp to minValue and maxValue", function()
		expect(TimeDurationUtils.format(30, "m", { minValue = 1 })).toBe("< 1")
		expect(TimeDurationUtils.format(30, "m __", { minValue = 1 })).toBe("< 1 minute")
		expect(TimeDurationUtils.format(90, "m __", { minValue = 1 })).toBe("2 minutes")
		expect(TimeDurationUtils.format({ days = 400 }, "d __", { maxValue = 365 })).toBe("> 365 days")
	end)

	it("should put the sign before the first shown token", function()
		expect(TimeDurationUtils.format(-(HOUR + MINUTE + SECOND), "h:mm:ss")).toBe("-1:01:01")
		expect(TimeDurationUtils.format(-45, "h:mm:ss")).toBe("-45")
		expect(TimeDurationUtils.format(-2 * MINUTE, "[T] m __")).toBe("T -2 minutes")
	end)

	it("should localize labels and let the locale place the number", function()
		expect(TimeDurationUtils.format({ hours = 2 }, "h __", { locale = "es-es" })).toBe("2 horas")
		expect(TimeDurationUtils.format({ hours = 1 }, "h __", { locale = "fr-fr" })).toBe("1 heure")
		expect(TimeDurationUtils.format({ days = 5 }, "d __", { locale = "ru-ru" })).toBe("5 дней")
		expect(TimeDurationUtils.format({ days = 2 }, "d__", { locale = "ko-kr" })).toBe("2일")
		expect(TimeDurationUtils.format({ days = 2 }, "d __", { locale = "ko-kr" })).toBe("2일")
		expect(TimeDurationUtils.format({ weeks = 2 }, "w __", { locale = "de-de" })).toBe("2 Wochen")
		local strings: TimeDurationUtils.DurationStringOverrides = {
			hours = { one = "%d hr", other = "%d hrs" },
		}
		expect(TimeDurationUtils.format({ hours = 2, minutes = 30 }, "h __ m __", { strings = strings })).toBe(
			"2 hrs 30 minutes"
		)
	end)

	it("should pick a template from the size of the duration", function()
		expect(TimeDurationUtils.format(0)).toBe("0 seconds")
		expect(TimeDurationUtils.format(0.25)).toBe("250 milliseconds")
		expect(TimeDurationUtils.format(45)).toBe("0:45")
		expect(TimeDurationUtils.format(123 * MINUTE)).toBe("2:03:00")
		expect(TimeDurationUtils.format({ days = 3 })).toBe("3 days")
		expect(TimeDurationUtils.format({ days = 14 })).toBe("2 weeks")
		expect(TimeDurationUtils.format({ days = 10, hours = 2 })).toBe("1 week, 3 days, 2 hours")
		expect(TimeDurationUtils.format({ days = 1, hours = 2 })).toBe("1 day, 2 hours")
		expect(TimeDurationUtils.format({ years = 2 })).toBe("2 years")
		expect(TimeDurationUtils.format({ years = 1, months = 2, days = 3 })).toBe("1 year, 2 months, 3 days")
	end)

	it("should reject a template without tokens", function()
		expect(function()
			TimeDurationUtils.format(5, "[none]")
		end).toThrow()
	end)
end)

describe("TimeDurationUtils.formatUnit", function()
	it("should pluralize the amount as given", function()
		expect(TimeDurationUtils.formatUnit("days", 1)).toBe("1 day")
		expect(TimeDurationUtils.formatUnit("days", 45)).toBe("45 days")
		expect(TimeDurationUtils.formatUnit("hours", 0)).toBe("0 hours")
		expect(TimeDurationUtils.formatUnit("h", 36)).toBe("36 hours")
		expect(TimeDurationUtils.formatUnit("ms", 250)).toBe("250 milliseconds")
		expect(TimeDurationUtils.formatUnit("weeks", 2)).toBe("2 weeks")
	end)

	it("should keep fractional and negative amounts", function()
		expect(TimeDurationUtils.formatUnit("minutes", 1.5)).toBe("1.5 minutes")
		expect(TimeDurationUtils.formatUnit("minutes", -1)).toBe("-1 minute")
	end)

	it("should localize and accept overrides", function()
		expect(TimeDurationUtils.formatUnit("days", 2, { locale = "es-es" })).toBe("2 días")
		expect(TimeDurationUtils.formatUnit("days", 2, { locale = "ru-ru" })).toBe("2 дня")
		local strings: TimeDurationUtils.DurationStringOverrides = {
			days = { one = "%dd", other = "%dd" },
		}
		expect(TimeDurationUtils.formatUnit("days", 2, { strings = strings })).toBe("2d")
	end)

	it("should reject units without a phrase", function()
		expect(function()
			TimeDurationUtils.formatUnit("quarters", 2)
		end).toThrow()
	end)
end)

describe("TimeDurationUtils.humanize", function()
	it("should describe the duration in words", function()
		expect(TimeDurationUtils.humanize(HOUR)).toBe("an hour")
		expect(TimeDurationUtils.humanize({ days = 2 })).toBe("2 days")
		expect(TimeDurationUtils.humanize(45 * SECOND)).toBe("a minute")
		expect(TimeDurationUtils.humanize("PT3H")).toBe("3 hours")
	end)

	it("should add a suffix by direction", function()
		expect(TimeDurationUtils.humanize(HOUR, true)).toBe("in an hour")
		expect(TimeDurationUtils.humanize(-HOUR, true)).toBe("an hour ago")
	end)

	it("should pass relative time options through", function()
		local hourStrings: RelativeTimeUtils.RelativeTimeStringOverrides = { h = "one hour" }
		local futureStrings: RelativeTimeUtils.RelativeTimeStringOverrides = { future = "%s from now" }

		expect(TimeDurationUtils.humanize(HOUR, false, { strings = hourStrings })).toBe("one hour")
		expect(TimeDurationUtils.humanize(HOUR, true, { strings = futureStrings })).toBe("an hour from now")
		expect(TimeDurationUtils.humanize(HOUR, true, { locale = "fr-fr" })).toBe("dans une heure")
	end)
end)

describe("TimeDurationUtils.toIsoString", function()
	it("should format ISO 8601 durations", function()
		expect(TimeDurationUtils.toIsoString({ hours = 1, minutes = 30 })).toBe("PT1H30M")
		expect(TimeDurationUtils.toIsoString({ days = 1 })).toBe("P1D")
		expect(TimeDurationUtils.toIsoString({ weeks = 1 })).toBe("P7D")
		expect(TimeDurationUtils.toIsoString({ years = 1, months = 2 })).toBe("P1Y2M")
		expect(TimeDurationUtils.toIsoString(1.5)).toBe("PT1.5S")
		expect(TimeDurationUtils.toIsoString(0)).toBe("P0D")
		expect(TimeDurationUtils.toIsoString(-5 * SECOND)).toBe("-PT5S")
	end)

	it("should round trip", function()
		for _, iso in { "PT1H30M", "P1DT12H", "P1Y2M3DT4H5M6S", "PT1.5S" } do
			expect(TimeDurationUtils.toIsoString(iso)).toBe(iso)
		end
	end)
end)
