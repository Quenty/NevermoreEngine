--!strict
--[[
	@class TimeLocalizationUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- The locales NumberLocalizationUtils covers
local LOCALES = {
	"en-us",
	"es-es",
	"fr-fr",
	"de-de",
	"pt-br",
	"zh-cn",
	"zh-cjv",
	"zh-tw",
	"ko-kr",
	"ja-jp",
	"it-it",
	"ru-ru",
	"id-id",
	"vi-vn",
	"th-th",
	"tr-tr",
	"pl-pl",
	"ar",
}

local CALENDAR_KEYS = { "sameDay", "nextDay", "nextWeek", "lastDay", "lastWeek", "sameElse" }
local RELATIVE_KEYS = { "future", "past", "s", "m", "mm", "h", "hh", "d", "dd", "M", "MM", "y", "yy" }
local DURATION_KEYS = { "years", "months", "weeks", "days", "hours", "minutes", "seconds", "milliseconds" }

describe("TimeLocalizationUtils", function()
	it("should default to English", function()
		expect(TimeLocalizationUtils.getCalendarFormatsForLocale(nil).sameDay).toBe("[Today at] LT")
		expect(TimeLocalizationUtils.getRelativeTimeStringsForLocale(nil).future).toBe("in %s")
		expect((TimeLocalizationUtils.getDurationStringsForLocale(nil).hours :: any).other).toBe("%d hours")
	end)

	it("should resolve regional variants to their language", function()
		expect(TimeLocalizationUtils.getCalendarFormatsForLocale("en-gb")).toBe(
			TimeLocalizationUtils.getCalendarFormatsForLocale("en-us")
		)
		expect(TimeLocalizationUtils.getRelativeTimeStringsForLocale("es-mx")).toBe(
			TimeLocalizationUtils.getRelativeTimeStringsForLocale("es-es")
		)
		expect(TimeLocalizationUtils.getDurationStringsForLocale("zh-hant")).toBe(
			TimeLocalizationUtils.getDurationStringsForLocale("zh-tw")
		)
		expect(TimeLocalizationUtils.getDurationStringsForLocale("zh-hans")).toBe(
			TimeLocalizationUtils.getDurationStringsForLocale("zh-cn")
		)
	end)

	it("should cover every NumberLocalizationUtils locale completely", function()
		for _, locale in LOCALES do
			local calendarFormats: any = TimeLocalizationUtils.getCalendarFormatsForLocale(locale)
			local relativeTimeStrings: any = TimeLocalizationUtils.getRelativeTimeStringsForLocale(locale)
			local durationStrings: any = TimeLocalizationUtils.getDurationStringsForLocale(locale)

			for _, key in CALENDAR_KEYS do
				expect(calendarFormats[key]).toEqual(expect.any("string"))
			end
			for _, key in RELATIVE_KEYS do
				expect(relativeTimeStrings[key] ~= nil).toBe(true)
			end
			for _, key in DURATION_KEYS do
				expect(durationStrings[key] ~= nil).toBe(true)
			end
		end
	end)

	it("should differ between languages", function()
		expect(TimeLocalizationUtils.getRelativeTimeStringsForLocale("fr-fr").past).toBe("il y a %s")
		expect(TimeLocalizationUtils.getRelativeTimeStringsForLocale("ja-jp").past).toBe("%s前")
		expect(TimeLocalizationUtils.getCalendarFormatsForLocale("de-de").sameDay).toBe("[heute um] LT [Uhr]")
	end)

	it("should expose the whole locale", function()
		local locale = TimeLocalizationUtils.getLocale("fr-fr")

		expect(locale.calendar).toBe(TimeLocalizationUtils.getCalendarFormatsForLocale("fr-fr"))
		expect(locale.relativeTime).toBe(TimeLocalizationUtils.getRelativeTimeStringsForLocale("fr-fr"))
		expect(locale.duration).toBe(TimeLocalizationUtils.getDurationStringsForLocale("fr-fr"))
		expect(TimeLocalizationUtils.getLocale("zh-cjv")).toBe(TimeLocalizationUtils.getLocale("zh-cn"))
	end)

	it("should return read-only tables", function()
		expect(table.isfrozen(TimeLocalizationUtils.getLocale("en-us"))).toBe(true)
		expect(table.isfrozen(TimeLocalizationUtils.getCalendarFormatsForLocale("en-us"))).toBe(true)
		expect(table.isfrozen(TimeLocalizationUtils.getRelativeTimeStringsForLocale("ru-ru"))).toBe(true)
		expect(table.isfrozen(TimeLocalizationUtils.getDurationStringsForLocale("pl-pl"))).toBe(true)
	end)
end)

describe("TimeLocalizationUtils locale resolution", function()
	it("should ignore case and accept underscores", function()
		local english = TimeLocalizationUtils.getLocale("en-us")

		expect(TimeLocalizationUtils.getLocale("EN-US")).toBe(english)
		expect(TimeLocalizationUtils.getLocale("en_US")).toBe(english)
		expect(TimeLocalizationUtils.getLocale("En")).toBe(english)
		expect(TimeLocalizationUtils.getLocale("Fr-CA")).toBe(TimeLocalizationUtils.getLocale("fr-fr"))
	end)

	it("should route Chinese by script and region", function()
		local simplified = TimeLocalizationUtils.getLocale("zh-cn")
		local traditional = TimeLocalizationUtils.getLocale("zh-tw")

		expect(simplified).never.toBe(traditional)
		expect(TimeLocalizationUtils.getLocale("zh")).toBe(simplified)
		expect(TimeLocalizationUtils.getLocale("zh-hans")).toBe(simplified)
		expect(TimeLocalizationUtils.getLocale("zh-sg")).toBe(simplified)
		expect(TimeLocalizationUtils.getLocale("zh-hant")).toBe(traditional)
		expect(TimeLocalizationUtils.getLocale("zh-hk")).toBe(traditional)
		expect(TimeLocalizationUtils.getLocale("zh-Hant-TW")).toBe(traditional)
	end)

	it("should fall back to English for nil, empty and unknown locales", function()
		local english = TimeLocalizationUtils.getLocale("en-us")

		expect(TimeLocalizationUtils.getLocale(nil)).toBe(english)
		expect(TimeLocalizationUtils.getLocale("")).toBe(english)
		expect(TimeLocalizationUtils.getLocale("xx-yy")).toBe(english)
		expect(TimeLocalizationUtils.getLocale("123")).toBe(english)
	end)

	it("should return the same table on every call", function()
		expect(TimeLocalizationUtils.getLocale("ja-jp")).toBe(TimeLocalizationUtils.getLocale("ja-jp"))
		expect(TimeLocalizationUtils.getCalendarFormatsForLocale("ja-jp")).toBe(
			TimeLocalizationUtils.getCalendarFormatsForLocale("ja")
		)
	end)

	it("should reject writes", function()
		expect(function()
			(TimeLocalizationUtils.getLocale("en-us") :: any).calendar = nil
		end).toThrow("readonly")
		expect(function()
			(TimeLocalizationUtils.getRelativeTimeStringsForLocale("en-us") :: any).s = "now"
		end).toThrow("readonly")
	end)
end)

describe("TimeLocalizationUtils string invariants", function()
	local AMOUNT_KEYS = { "mm", "hh", "dd", "MM", "yy" }

	it("should give every locale a %s slot in future and past", function()
		for _, locale in LOCALES do
			local strings = TimeLocalizationUtils.getRelativeTimeStringsForLocale(locale)

			expect(string.find(strings.future, "%%s") ~= nil).toBe(true)
			expect(string.find(strings.past, "%%s") ~= nil).toBe(true)
		end
	end)

	it("should put the amount into every plural relative time string", function()
		for _, locale in LOCALES do
			local strings: any = TimeLocalizationUtils.getRelativeTimeStringsForLocale(locale)

			for _, key in AMOUNT_KEYS do
				local value = strings[key]
				if type(value) == "function" then
					expect(string.find(value(7, false, key, true), "7", 1, true) ~= nil).toBe(true)
					expect(string.find(value(7, true, key, false), "7", 1, true) ~= nil).toBe(true)
				else
					expect(string.find(value, "%%d") ~= nil).toBe(true)
				end
			end
		end
	end)

	it("should return a string from every function valued relative time string", function()
		for _, locale in LOCALES do
			local strings: any = TimeLocalizationUtils.getRelativeTimeStringsForLocale(locale)

			for _, key in RELATIVE_KEYS do
				local value = strings[key]
				if type(value) == "function" then
					expect(value(1, true, key, false)).toEqual(expect.any("string"))
					expect(value(1, false, key, true)).toEqual(expect.any("string"))
					expect(value(2, false, key, false)).toEqual(expect.any("string"))
				end
			end
		end
	end)

	it("should put the amount into every duration phrase", function()
		for _, locale in LOCALES do
			local strings: any = TimeLocalizationUtils.getDurationStringsForLocale(locale)

			for _, key in DURATION_KEYS do
				local phrase = strings[key]
				if type(phrase) == "function" then
					expect(string.find(phrase(3), "3", 1, true) ~= nil).toBe(true)
					expect(string.find(phrase(1), "1", 1, true) ~= nil).toBe(true)
				else
					expect(string.find(phrase.one, "%%d") ~= nil).toBe(true)
					expect(string.find(phrase.other, "%%d") ~= nil).toBe(true)
				end
			end
		end
	end)

	it("should give every calendar phrase a time except sameElse", function()
		for _, locale in LOCALES do
			local formats: any = TimeLocalizationUtils.getCalendarFormatsForLocale(locale)

			for _, key in CALENDAR_KEYS do
				if key == "sameElse" then
					expect(formats[key]).toBe("L")
				else
					expect(string.find(formats[key], "LT", 1, true) ~= nil).toBe(true)
				end
			end

			expect(string.find(formats.nextWeek, "ddd", 1, true) ~= nil).toBe(true)
			expect(string.find(formats.lastWeek, "ddd", 1, true) ~= nil).toBe(true)
		end
	end)
end)
