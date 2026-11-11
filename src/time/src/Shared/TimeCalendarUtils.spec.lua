--!strict
--[[
	@class TimeCalendarUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TimeCalendarUtils = require("TimeCalendarUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local REFERENCE = "2025-09-22T13:00:00Z" -- a Monday

local function calendar(currentTime: string): string
	return TimeCalendarUtils.calendar(currentTime, REFERENCE)
end

describe("TimeCalendarUtils.calendar", function()
	it("should describe the reference day", function()
		expect(calendar("2025-09-22T09:05:00Z")).toBe("Today at 9:05 AM")
		expect(calendar("2025-09-22T00:00:00Z")).toBe("Today at 12:00 AM")
		expect(calendar("2025-09-22T23:59:59Z")).toBe("Today at 11:59 PM")
	end)

	it("should describe the surrounding days", function()
		expect(calendar("2025-09-23T18:30:00Z")).toBe("Tomorrow at 6:30 PM")
		expect(calendar("2025-09-21T00:00:00Z")).toBe("Yesterday at 12:00 AM")
		expect(calendar("2025-09-21T23:59:59Z")).toBe("Yesterday at 11:59 PM")
	end)

	it("should name the weekday within a week either way", function()
		expect(calendar("2025-09-24T10:00:00Z")).toBe("Wednesday at 10:00 AM")
		expect(calendar("2025-09-28T23:59:00Z")).toBe("Sunday at 11:59 PM")
		expect(calendar("2025-09-20T08:00:00Z")).toBe("Last Saturday at 8:00 AM")
		expect(calendar("2025-09-16T00:00:00Z")).toBe("Last Tuesday at 12:00 AM")
	end)

	it("should fall back to a date further out", function()
		expect(calendar("2025-09-29T00:00:00Z")).toBe("09/29/2025")
		expect(calendar("2025-09-15T23:59:59Z")).toBe("09/15/2025")
		expect(calendar("2026-01-01T00:00:00Z")).toBe("01/01/2026")
	end)

	it("should measure from the start of the reference day", function()
		expect(TimeCalendarUtils.calendar("2025-09-23T00:00:00Z", "2025-09-22T23:59:59Z")).toBe("Tomorrow at 12:00 AM")
		expect(TimeCalendarUtils.calendar("2025-09-22T00:00:00Z", "2025-09-22T23:59:59Z")).toBe("Today at 12:00 AM")
	end)

	it("should default the reference to now", function()
		expect(string.sub(TimeCalendarUtils.calendar(nil, nil), 1, 8)).toBe("Today at")
		expect(string.sub(TimeCalendarUtils.calendar(DateTime.now().UnixTimestamp + 86400, nil), 1, 11)).toBe(
			"Tomorrow at"
		)
	end)

	it("should accept template overrides with fallbacks", function()
		local formats = { sameDay = "[Today]", sameElse = "YYYY-MM-DD" }

		expect(TimeCalendarUtils.calendar("2025-09-22T09:05:00Z", REFERENCE, formats)).toBe("Today")
		expect(TimeCalendarUtils.calendar("2026-01-01T00:00:00Z", REFERENCE, formats)).toBe("2026-01-01")
		expect(TimeCalendarUtils.calendar("2025-09-23T18:30:00Z", REFERENCE, formats)).toBe("Tomorrow at 6:30 PM")
	end)

	it("should accept function overrides", function()
		local formats: TimeCalendarUtils.CalendarFormats = {
			nextWeek = function(dateTime: DateTime, referenceTime: DateTime): string
				return string.format("%d days out", (dateTime.UnixTimestamp - referenceTime.UnixTimestamp) // 86400)
			end,
		}

		expect(TimeCalendarUtils.calendar("2025-09-25T13:00:00Z", REFERENCE, formats)).toBe("3 days out")
	end)

	it("should use the locale's phrases and templates", function()
		local wednesday = TimeCalendarUtils.calendar("2025-09-24T10:00:00Z", REFERENCE, nil, "fr-fr")
		local today = TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, nil, "es-es")
		local yesterday = TimeCalendarUtils.calendar("2025-09-21T10:00:00Z", REFERENCE, nil, "de-de")
		local tomorrow = TimeCalendarUtils.calendar("2025-09-23T10:00:00Z", REFERENCE, nil, "ja-jp")

		expect(string.find(wednesday, "^mercredi à ") ~= nil).toBe(true)
		expect(string.find(today, "^hoy a las ") ~= nil).toBe(true)
		expect(string.find(yesterday, "^gestern um .* Uhr$") ~= nil).toBe(true)
		expect(string.find(tomorrow, "^明日 ") ~= nil).toBe(true)
	end)

	it("should let overrides win over the locale", function()
		expect(TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, { sameDay = "[hoy]" }, "es-es")).toBe(
			"hoy"
		)
	end)
end)

describe("TimeCalendarUtils localization edge cases", function()
	it("should apply the locale to string overrides", function()
		expect(TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, { sameDay = "dddd" }, "fr-fr")).toBe(
			"lundi"
		)
		expect(TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, { sameDay = "dddd" }, "de-de")).toBe(
			"Montag"
		)
	end)

	it("should fill missing overrides from the locale, not English", function()
		local tomorrow = TimeCalendarUtils.calendar("2025-09-23T10:00:00Z", REFERENCE, { sameDay = "[x]" }, "es-es")

		expect(string.find(tomorrow, "^mañana a las ") ~= nil).toBe(true)
	end)

	it("should localize the fallback date", function()
		local american = TimeCalendarUtils.calendar("2026-01-05T00:00:00Z", REFERENCE, nil, "en-us")
		local french = TimeCalendarUtils.calendar("2026-01-05T00:00:00Z", REFERENCE, nil, "fr-fr")

		expect(american).toBe("01/05/2026")
		expect(french).never.toBe(american)
		expect(string.find(french, "^%d%d[/.]%d%d[/.]%d%d%d%d$") ~= nil).toBe(true)
	end)

	it("should keep languages that do not space before the time", function()
		local today = TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, nil, "zh-cn")

		expect(string.find(today, "^今天%d") ~= nil).toBe(true)
	end)

	it("should treat the zh-cjv alias like zh-cn", function()
		expect(TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, nil, "zh-cjv")).toBe(
			TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, nil, "zh-cn")
		)
	end)

	it("should name the weekday in the locale for next and last week", function()
		local next = TimeCalendarUtils.calendar("2025-09-25T10:00:00Z", REFERENCE, nil, "pt-br")
		local last = TimeCalendarUtils.calendar("2025-09-18T10:00:00Z", REFERENCE, nil, "pt-br")

		expect(string.find(next, "^Quinta%-feira às ") ~= nil).toBe(true)
		expect(string.find(last, "^Quinta%-feira passado às ") ~= nil).toBe(true)
	end)

	it("should fall back to English for an unknown locale", function()
		expect(TimeCalendarUtils.calendar("2025-09-22T09:05:00Z", REFERENCE, nil, "xx-yy")).toBe("Today at 9:05 AM")
	end)

	it("should give function overrides the raw times regardless of locale", function()
		local formats: TimeCalendarUtils.CalendarFormats = {
			sameDay = function(dateTime: DateTime, referenceTime: DateTime): string
				return dateTime:ToIsoDate() .. " vs " .. referenceTime:ToIsoDate()
			end,
		}

		expect(TimeCalendarUtils.calendar("2025-09-22T10:00:00Z", REFERENCE, formats, "ja-jp")).toBe(
			"2025-09-22T10:00:00Z vs 2025-09-22T13:00:00Z"
		)
	end)
end)
