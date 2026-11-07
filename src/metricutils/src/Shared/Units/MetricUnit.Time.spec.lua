--!strict
--[[
	@class MetricUnit.Time.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitScale = require("MetricUnitScale")
local TimeDurationUtils = require("TimeDurationUtils")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local format = MetricUnit.format

describe("MetricUnit.format durations", function()
	it("writes averaged years and months whole", function()
		expect(format(MetricUnit.years(1))).toBe("1 year")
		expect(format(MetricUnit.months(1))).toBe("1 month")
		expect(format(MetricUnit.years(1) / 12)).toBe("1 month")
		expect(format(MetricUnit.months(12))).toBe("1 year")
		expect(format(MetricUnit.years(100))).toBe("100 years")
		expect(format(MetricUnit.years(1) + MetricUnit.days(1))).toBe("1 year, 1 day")
	end)

	it("breaks a duration into its two largest units", function()
		expect(format(MetricUnit.minutes(90))).toBe("1 hour, 30 minutes")
		expect(format(MetricUnit.days(1.5))).toBe("1 day, 12 hours")
		expect(format(MetricUnit.hours(36.6))).toBe("1 day, 13 hours")
		expect(format(MetricUnit.seconds(45))).toBe("45 seconds")
		expect(format(MetricUnit.years(1234))).toBe("1,234 years")
	end)

	it("carries a rounded unit into the next larger one", function()
		expect(format(MetricUnit.days(1) + MetricUnit.hours(23) + MetricUnit.minutes(59.7))).toBe("2 days")
		expect(format(MetricUnit.minutes(59.9), { maxParts = 1 })).toBe("1 hour")
	end)

	it("takes how many units to show and the separator", function()
		expect(format(MetricUnit.minutes(90), { maxParts = 1 })).toBe("2 hours")
		expect(format(MetricUnit.days(1) + MetricUnit.hours(2) + MetricUnit.minutes(3), { maxParts = 3 })).toBe(
			"1 day, 2 hours, 3 minutes"
		)
		expect(format(MetricUnit.minutes(90), { separator = " " })).toBe("1 hour 30 minutes")
	end)

	it("writes zero, milliseconds and less than a millisecond", function()
		expect(format(MetricUnit.seconds(0))).toBe("0 seconds")
		expect(format(MetricUnit.milliseconds(250))).toBe("250 milliseconds")
		expect(format(MetricUnit.microseconds(40))).toBe("40 microseconds")
	end)

	it("signs a negative duration once", function()
		expect(format(-MetricUnit.minutes(90))).toBe("-1 hour, 30 minutes")
	end)

	it("writes one fixed time unit with a fractional amount", function()
		expect(format(MetricUnit.minutes(90), { unit = "hour" })).toBe("1.5 hours")
		expect(format(MetricUnit.hours(1), { unit = "hour" })).toBe("1 hour")
		expect(format(MetricUnit.hours(36), { unit = "day", locale = "es-es" })).toBe("1,5 días")
	end)

	it("uses @quenty/time's localized duration words", function()
		expect(format(MetricUnit.minutes(90), { locale = "es-es" })).toBe("1 hora, 30 minutos")
		expect(format(MetricUnit.days(2), { locale = "fr-fr" })).toBe("2 jours")
		expect(format(MetricUnit.hours(2), { locale = "ru-ru" })).toBe("2 часа")
		local hours: TimeLocalizationUtils.DurationPhrase = { one = "%d hr", other = "%d hrs" }
		expect(format(MetricUnit.minutes(90), { durationStrings = { hours = hours } })).toBe("1 hr, 30 minutes")
	end)
end)

describe("MetricUnit and @quenty/time", function()
	it("hands exact seconds to TimeDurationUtils", function()
		expect(MetricUnit.minutes(2):InSeconds()).toBe(120)
		expect(TimeDurationUtils.format(MetricUnit.hours(36):InSeconds(), "h:mm")).toBe("36:00")
		expect(MetricUnit.years(1):InSeconds()).toBe(MetricUnitScale.YEAR)
	end)

	it("measures the exact time between two DateTimes", function()
		local start = MetricUnit.fromDateTime(DateTime.fromUnixTimestamp(0))
		local later = MetricUnit.fromDateTime(DateTime.fromUnixTimestamp(90))
		expect((later - start):InSeconds()).toBe(90)
		expect((start - later):InSeconds()).toBe(-90)
		expect(MetricUnit.isKind(later - start, "time")).toBe(true)

		-- A calendar year with a leap day is 366 days, longer than the averaged year
		local leapYear = MetricUnit.fromDateTime(DateTime.fromUniversalTime(2025, 1, 1))
			- MetricUnit.fromDateTime(DateTime.fromUniversalTime(2024, 1, 1))
		expect(leapYear:In("day")).toBe(366)
		expect(leapYear > MetricUnit.years(1)).toBe(true)
	end)

	it("moves a DateTime by an exact span", function()
		local start = MetricUnit.fromDateTime(DateTime.fromUnixTimestamp(0))
		expect((start + MetricUnit.hours(1)):ToDateTime().UnixTimestamp).toBe(3600)
		expect((start + MetricUnit.months(1)):ToDateTime().UnixTimestampMillis).toBe(MetricUnitScale.MONTH * 1000)
	end)
end)

describe("MetricUnit instants", function()
	it("subtracts two instants to a span, and adds a span to an instant", function()
		local worldStart = MetricUnit.instant(0)
		local now = worldStart + MetricUnit.years(250)
		expect(MetricUnit.isKind(now, "instant")).toBe(true)
		expect(now:IsAbsolute()).toBe(true)
		expect(now:GetKind()).toBe("instant")
		expect((now - worldStart):GetKind()).toBe("time")
		expect((now - worldStart):In("year")).toBeCloseTo(250, 9)
		expect((MetricUnit.years(1) + now - now):In("year")).toBeCloseTo(1, 9)
		expect(MetricUnit.isKind(now - MetricUnit.days(1), "instant")).toBe(true)
		expect(MetricUnit.isKind(now, "time")).toBe(false)
	end)

	it("reads an instant as the time since its epoch", function()
		local instant = MetricUnit.instant(5400)
		expect(instant:InSeconds()).toBe(5400)
		expect(instant:In("hour")).toBe(1.5)
		expect(function()
			instant:In("meter")
		end).toThrow('In("meter") reads length, not instant')
	end)

	it("rejects adding, scaling and negating instants", function()
		local instant = MetricUnit.instant(10)
		expect(function()
			local _ = instant + instant
		end).toThrow("cannot add two instants; subtract them for a difference, or add a difference to one")
		expect(function()
			local _ = MetricUnit.seconds(1) - instant
		end).toThrow("cannot subtract an instant from a time")
		expect(function()
			local _ = instant * 2
		end).toThrow("cannot multiply an instant")
		expect(function()
			local _ = -instant
		end).toThrow("cannot negate an instant")
		expect(function()
			MetricUnit.abs(instant)
		end).toThrow("cannot take the size of an instant")
		expect(function()
			local _ = instant < MetricUnit.seconds(20)
		end).toThrow("cannot compare an instant and a time")
	end)

	it("expects instants and spans apart", function()
		expect(MetricUnit.expect(MetricUnit.instant(7), "instant", "at")).toBe(7)
		expect(function()
			MetricUnit.expect(MetricUnit.seconds(7), "instant", "at")
		end).toThrow("MetricUnit.expect: at expects instant, got time")
		expect(function()
			MetricUnit.expect(MetricUnit.instant(7), "time", "every")
		end).toThrow("MetricUnit.expect: every expects time, got instant")
	end)

	it("round trips through DateTime and plain data", function()
		local dateTime = DateTime.fromUnixTimestampMillis(1_700_000_000_123)
		expect(MetricUnit.fromDateTime(dateTime):ToDateTime().UnixTimestampMillis).toBe(1_700_000_000_123)
		expect(function()
			MetricUnit.seconds(5):ToDateTime()
		end).toThrow("ToDateTime takes an instant, not time")

		local data = MetricUnit.toData(MetricUnit.instant(42))
		expect(data).toEqual({ amount = 42, dimensions = { time = 1 }, absolute = true })
		expect(MetricUnit.isKind(MetricUnit.fromData(data), "instant")).toBe(true)
	end)

	it("writes an instant apart from a span", function()
		expect(tostring(MetricUnit.instant(90))).toBe("epoch + 1.5 min")
		expect(tostring(MetricUnit.seconds(90))).toBe("1.5 min")
		expect(MetricUnit.format(MetricUnit.instant(5400))).toBe("1 hour, 30 minutes")
	end)
end)
