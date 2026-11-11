--!strict
--[[
	@class RelativeTimeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RelativeTimeUtils = require("RelativeTimeUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local BASE = 1758499200 -- 2025-09-22 Monday 00:00:00 UTC
local WITHOUT_SUFFIX = { withoutSuffix = true }

describe("RelativeTimeUtils.from", function()
	local function fromOffset(seconds: number): string
		return RelativeTimeUtils.from(BASE + seconds, BASE, WITHOUT_SUFFIX)
	end

	it("should pick the threshold for seconds, minutes and hours", function()
		expect(fromOffset(0)).toBe("a few seconds")
		expect(fromOffset(44)).toBe("a few seconds")
		expect(fromOffset(45)).toBe("a minute")
		expect(fromOffset(89)).toBe("a minute")
		expect(fromOffset(90)).toBe("2 minutes")
		expect(fromOffset(44 * 60)).toBe("44 minutes")
		expect(fromOffset(45 * 60)).toBe("an hour")
		expect(fromOffset(89 * 60)).toBe("an hour")
		expect(fromOffset(90 * 60)).toBe("2 hours")
		expect(fromOffset(21 * 3600)).toBe("21 hours")
	end)

	it("should pick the threshold for days and months", function()
		expect(fromOffset(22 * 3600)).toBe("a day")
		expect(fromOffset(35 * 3600)).toBe("a day")
		expect(fromOffset(36 * 3600)).toBe("2 days")
		expect(fromOffset(25 * 86400)).toBe("25 days")
		expect(fromOffset(26 * 86400)).toBe("a month")
		expect(fromOffset(45 * 86400)).toBe("a month")
		expect(fromOffset(46 * 86400)).toBe("2 months")
	end)

	it("should count months and years on the calendar", function()
		expect(RelativeTimeUtils.from("2026-07-22T00:00:00Z", BASE, WITHOUT_SUFFIX)).toBe("10 months")
		expect(RelativeTimeUtils.from("2026-08-22T00:00:00Z", BASE, WITHOUT_SUFFIX)).toBe("a year")
		expect(RelativeTimeUtils.from("2027-02-22T00:00:00Z", BASE, WITHOUT_SUFFIX)).toBe("a year")
		expect(RelativeTimeUtils.from("2027-03-22T00:00:00Z", BASE, WITHOUT_SUFFIX)).toBe("2 years")
		expect(RelativeTimeUtils.from("2035-09-22T00:00:00Z", BASE, WITHOUT_SUFFIX)).toBe("10 years")
		expect(RelativeTimeUtils.from("2025-02-28T00:00:00Z", "2025-01-31T00:00:00Z", WITHOUT_SUFFIX)).toBe("a month")
	end)

	it("should say in for the future and ago for the past", function()
		expect(RelativeTimeUtils.from(BASE + 86400, BASE)).toBe("in a day")
		expect(RelativeTimeUtils.from(BASE - 86400, BASE)).toBe("a day ago")
		expect(RelativeTimeUtils.from(BASE, BASE)).toBe("a few seconds ago")
		expect(RelativeTimeUtils.from(BASE - 3 * 3600, BASE)).toBe("3 hours ago")
	end)

	it("should accept any DateTimeLike on both sides", function()
		expect(RelativeTimeUtils.from(DateTime.fromUnixTimestamp(BASE + 3600), "2025-09-22T00:00:00Z")).toBe(
			"in an hour"
		)
	end)
end)

describe("RelativeTimeUtils.to", function()
	it("should mirror from", function()
		expect(RelativeTimeUtils.to(BASE, BASE + 86400)).toBe("in a day")
		expect(RelativeTimeUtils.to(BASE + 86400, BASE)).toBe("a day ago")
		expect(RelativeTimeUtils.to(BASE, BASE + 90, WITHOUT_SUFFIX)).toBe("2 minutes")
	end)
end)

describe("RelativeTimeUtils.fromNow / toNow", function()
	it("should compare against the current time", function()
		local hourAgo = DateTime.now().UnixTimestamp - 3600

		expect(RelativeTimeUtils.fromNow(hourAgo)).toBe("an hour ago")
		expect(RelativeTimeUtils.fromNow(hourAgo, WITHOUT_SUFFIX)).toBe("an hour")
		expect(RelativeTimeUtils.toNow(hourAgo)).toBe("in an hour")
		expect(RelativeTimeUtils.fromNow(nil)).toBe("a few seconds ago")
	end)
end)

describe("RelativeTimeUtils.from with options", function()
	it("should use custom thresholds and strings", function()
		local thresholds: { RelativeTimeUtils.RelativeTimeThreshold } = {
			{ key = "s", limit = 59, unit = "second" },
			{ key = "mm", limit = 59, unit = "minute" },
			{ key = "hh", limit = 23, unit = "hour" },
			{ key = "ww", limit = 3, unit = "week" },
			{ key = "dd", unit = "day" },
		}
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = {
			s = "%d seconds",
			ww = "%d weeks",
		}
		local options: RelativeTimeUtils.RelativeTimeOptions = {
			withoutSuffix = true,
			thresholds = thresholds,
			strings = strings,
		}

		expect(RelativeTimeUtils.from(BASE + 30, BASE, options)).toBe("30 seconds")
		expect(RelativeTimeUtils.from(BASE + 90, BASE, options)).toBe("2 minutes")
		expect(RelativeTimeUtils.from(BASE + 5 * 3600, BASE, options)).toBe("5 hours")
		expect(RelativeTimeUtils.from(BASE + 14 * 86400, BASE, options)).toBe("2 weeks")
		expect(RelativeTimeUtils.from(BASE + 40 * 86400, BASE, options)).toBe("40 days")
	end)

	it("should override the suffix strings", function()
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = { future = "%s from now", past = "%s earlier" }
		local options = { strings = strings }

		expect(RelativeTimeUtils.from(BASE + 3600, BASE, options)).toBe("an hour from now")
		expect(RelativeTimeUtils.from(BASE - 3600, BASE, options)).toBe("an hour earlier")
	end)

	it("should use custom rounding", function()
		expect(RelativeTimeUtils.from(BASE + 90, BASE, { withoutSuffix = true, rounding = math.floor })).toBe(
			"a minute"
		)
		expect(RelativeTimeUtils.from(BASE + 90, BASE, { withoutSuffix = true, rounding = math.ceil })).toBe(
			"2 minutes"
		)
	end)

	it("should error on a threshold key without a string", function()
		local thresholds: { RelativeTimeUtils.RelativeTimeThreshold } = { { key = "nope", unit = "second" } }

		expect(function()
			RelativeTimeUtils.from(BASE + 30, BASE, { thresholds = thresholds })
		end).toThrow("No relative time string")
	end)
end)

describe("RelativeTimeUtils.from with a locale", function()
	local function from(seconds: number, locale: string, withoutSuffix: boolean?): string
		return RelativeTimeUtils.from(BASE + seconds, BASE, { locale = locale, withoutSuffix = withoutSuffix })
	end

	it("should use the locale's strings and suffixes", function()
		expect(from(-60, "fr-fr")).toBe("il y a une minute")
		expect(from(3 * 3600, "es-es")).toBe("en 3 horas")
		expect(from(-2 * 86400, "pt-br")).toBe("há 2 dias")
		expect(from(60, "ja-jp")).toBe("1分後")
		expect(from(3 * 86400, "zh-cn")).toBe("3 天内")
		expect(from(-3 * 86400, "zh-tw")).toBe("3 天前")
		expect(from(3600, "ko-kr")).toBe("한 시간 후")
		expect(from(5 * 60, "tr-tr")).toBe("5 dakika sonra")
	end)

	it("should inflect German after in and vor", function()
		expect(from(60, "de-de")).toBe("in einer Minute")
		expect(from(-60, "de-de")).toBe("vor einer Minute")
		expect(from(60, "de-de", true)).toBe("eine Minute")
		expect(from(-3 * 86400, "de-de")).toBe("vor 3 Tagen")
		expect(from(3 * 86400, "de-de", true)).toBe("3 Tage")
	end)

	it("should pick Russian and Polish plural forms", function()
		expect(from(2 * 60, "ru-ru")).toBe("через 2 минуты")
		expect(from(5 * 60, "ru-ru")).toBe("через 5 минут")
		expect(from(21 * 60, "ru-ru")).toBe("через 21 минуту")
		expect(from(21 * 60, "ru-ru", true)).toBe("21 минута")
		expect(from(-60, "ru-ru")).toBe("минуту назад")
		expect(from(2 * 3600, "pl-pl")).toBe("za 2 godziny")
		expect(from(5 * 3600, "pl-pl")).toBe("za 5 godzin")
		expect(from(60, "pl-pl")).toBe("za minutę")
		expect(from(60, "pl-pl", true)).toBe("minuta")
	end)

	it("should resolve regional variants and let overrides win", function()
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = { h = "une petite heure" }

		expect(from(-60, "fr-ca")).toBe("il y a une minute")
		expect(RelativeTimeUtils.from(BASE + 3600, BASE, { locale = "fr-fr", strings = strings })).toBe(
			"dans une petite heure"
		)
	end)
end)

describe("RelativeTimeUtils localization edge cases", function()
	local function from(seconds: number, locale: string, withoutSuffix: boolean?): string
		return RelativeTimeUtils.from(BASE + seconds, BASE, { locale = locale, withoutSuffix = withoutSuffix })
	end

	it("should call function valued strings with the amount, suffix flag, key and direction", function()
		local calls: { { any } } = {}
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = {
			mm = function(amount: number, withoutSuffix: boolean, key: string, isFuture: boolean): string
				table.insert(calls, { amount :: any, withoutSuffix, key, isFuture })
				return "custom"
			end,
		}

		expect(RelativeTimeUtils.from(BASE + 5 * 60, BASE, { strings = strings })).toBe("in custom")
		expect(RelativeTimeUtils.from(BASE - 5 * 60, BASE, { strings = strings, withoutSuffix = true })).toBe("custom")
		expect(calls).toEqual({
			{ 5 :: any, false, "mm", true },
			{ 5 :: any, true, "mm", false },
		})
	end)

	it("should let a string override replace a locale's function", function()
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = { m = "1 Min." }

		expect(RelativeTimeUtils.from(BASE + 60, BASE, { locale = "de-de", strings = strings })).toBe("in 1 Min.")
		expect(RelativeTimeUtils.from(BASE + 3600, BASE, { locale = "de-de", strings = strings })).toBe(
			"in einer Stunde"
		)
	end)

	it("should reject function valued future and past", function()
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = {
			future = function(): string
				return "soon"
			end,
		}

		expect(function()
			RelativeTimeUtils.from(BASE + 60, BASE, { strings = strings })
		end).toThrow("future and past must be strings")
	end)

	it("should use the singular step for a rounded amount of 1 in every locale", function()
		expect(from(60, "de-de")).toBe("in einer Minute")
		expect(from(60 * 60, "ru-ru")).toBe("через час")
		expect(from(-24 * 3600, "pl-pl")).toBe("1 dzień temu")
		expect(from(24 * 3600, "ja-jp")).toBe("1日後")
	end)

	it("should treat 11 to 14 as many in Russian even past 100", function()
		expect(from(11 * 60, "ru-ru")).toBe("через 11 минут")
		expect(from(12 * 3600, "ru-ru")).toBe("через 12 часов")
		expect(from(14 * 3600, "ru-ru")).toBe("через 14 часов")
		expect(RelativeTimeUtils.from("2136-09-22T00:00:00Z", BASE, { locale = "ru-ru", withoutSuffix = true })).toBe(
			"111 лет"
		)
		expect(RelativeTimeUtils.from("2126-09-22T00:00:00Z", BASE, { locale = "ru-ru" })).toBe("через 101 год")
	end)

	it("should keep Polish teens and 22 apart", function()
		expect(from(12 * 3600, "pl-pl")).toBe("za 12 godzin")
		expect(from(22 * 60, "pl-pl")).toBe("za 22 minuty")
		expect(RelativeTimeUtils.from("2137-09-22T00:00:00Z", BASE, { locale = "pl-pl", withoutSuffix = true })).toBe(
			"112 lat"
		)
		expect(RelativeTimeUtils.from("2047-09-22T00:00:00Z", BASE, { locale = "pl-pl" })).toBe("za 22 lata")
		expect(RelativeTimeUtils.from("2037-09-22T00:00:00Z", BASE, { locale = "pl-pl" })).toBe("za 12 lat")
	end)

	it("should inflect German months and years after vor", function()
		expect(RelativeTimeUtils.from("2025-07-01T00:00:00Z", BASE, { locale = "de-de" })).toBe("vor 3 Monaten")
		expect(RelativeTimeUtils.from("2025-07-01T00:00:00Z", BASE, { locale = "de-de", withoutSuffix = true })).toBe(
			"3 Monate"
		)
		expect(RelativeTimeUtils.from("2020-09-22T00:00:00Z", BASE, { locale = "de-de" })).toBe("vor 5 Jahren")
		expect(RelativeTimeUtils.from("2024-09-22T00:00:00Z", BASE, { locale = "de-de" })).toBe("vor einem Jahr")
	end)

	it("should place the suffix where the language puts it", function()
		expect(from(3600, "it-it")).toBe("tra un'ora")
		expect(from(-3600, "it-it")).toBe("un'ora fa")
		expect(from(-3600, "id-id")).toBe("sejam yang lalu")
		expect(from(2 * 86400, "vi-vn")).toBe("2 ngày tới")
		expect(from(-2 * 86400, "th-th")).toBe("2 วันที่แล้ว")
		expect(from(2 * 86400, "ar")).toBe("بعد 2 أيام")
	end)

	it("should combine a locale with custom thresholds", function()
		local thresholds: { RelativeTimeUtils.RelativeTimeThreshold } = {
			{ key = "s", limit = 59, unit = "second" },
			{ key = "mm", limit = 59, unit = "minute" },
			{ key = "hh", limit = 23, unit = "hour" },
			{ key = "ww", unit = "week" },
		}
		local strings: RelativeTimeUtils.RelativeTimeStringOverrides = { ww = "%d semaines" }

		expect(
			RelativeTimeUtils.from(
				BASE + 14 * 86400,
				BASE,
				{ locale = "fr-fr", thresholds = thresholds, strings = strings }
			)
		).toBe("dans 2 semaines")
		expect(
			RelativeTimeUtils.from(
				BASE + 5 * 3600,
				BASE,
				{ locale = "fr-fr", thresholds = thresholds, strings = strings }
			)
		).toBe("dans 5 heures")
		expect(function()
			RelativeTimeUtils.from(BASE + 14 * 86400, BASE, { locale = "fr-fr", thresholds = thresholds })
		end).toThrow("No relative time string")
	end)

	it("should resolve the locale loosely", function()
		expect(from(-60, "FR-FR")).toBe("il y a une minute")
		expect(from(-60, "fr_CA")).toBe("il y a une minute")
		expect(from(-60, "zh-Hant")).toBe("1 分鐘前")
		expect(from(-60, "xx-yy")).toBe("a minute ago")
	end)
end)
