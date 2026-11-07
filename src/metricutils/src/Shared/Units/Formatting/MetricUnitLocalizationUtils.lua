--!strict
--[=[
	Locale strings for [MetricUnitFormatUtils]: each unit's short and long phrase, and the phrases for "per" a time
	unit. Lookups resolve through [ResolveLocaleUtils], so `en-us` lands on American English and `en-au` on
	Commonwealth English, and an unknown locale falls back to American English with a warning.

	Short phrases use the unit symbols, which are the same in every language. Long phrases are names, so they need a
	locale; only English ships today. To add a locale, add one entry to `LOCALES`. Every field is required, so a
	missing phrase is a type error rather than a runtime surprise. Duration words come from [TimeLocalizationUtils].

	@class MetricUnitLocalizationUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitCatalog = require("MetricUnitCatalog")
local ResolveLocaleUtils = require("ResolveLocaleUtils")

local MetricUnitLocalizationUtils = {}

local DEFAULT_LOCALE = "en-us"

--[=[
	A unit phrase with `%s` for the already formatted number: a singular and plural pair, or a function of the
	rounded amount and the formatted number for languages with more plural forms.

	@type UnitPhrase { one: string, other: string } | (amount: number, numberText: string) -> string
	@within MetricUnitLocalizationUtils
]=]
export type UnitPhrase = { one: string, other: string } | (number, string) -> string

--[=[
	The short and long phrase for one unit, such as `"%s km"` and `"%s kilometers"`.

	@interface UnitNames
	.short UnitPhrase
	.long UnitPhrase
	@within MetricUnitLocalizationUtils
]=]
export type UnitNames = { short: UnitPhrase, long: UnitPhrase }

--[=[
	[UnitNames] for every unit written by name: microsecond, hertz, millimeter, centimeter, meter, kilometer, inch, foot, yard, mile, stud, squareMillimeter, squareCentimeter, squareMeter, hectare, squareKilometer, squareFoot, acre, milliliter, liter, cubicMeter, usFluidOunce, usGallon, imperialGallon, byte, kilobyte, megabyte, gigabyte, kibibyte, mebibyte, gibibyte, bytePerSecond, kilobytePerSecond, milligram, gram, kilogram, tonne, ounce, pound, stone, meterPerSecond, kilometerPerHour, milePerHour, knot, studPerSecond, meterPerSecondSquared, newton, kilonewton, meganewton, poundForce, joule, kilojoule, megajoule, kilowattHour, kilocalorie, watt, kilowatt, megawatt, pascal, kilopascal, megapascal, bar, poundForcePerSquareInch, kilogramPerCubicMeter, gramPerCubicCentimeter, kelvin, celsius, fahrenheit. Time units are written with
	[TimeLocalizationUtils]' duration words instead, and bare rates with [PerStrings].

	@type UnitStrings { [UnitId]: UnitNames }
	@within MetricUnitLocalizationUtils
]=]
export type UnitStrings = {
	microsecond: UnitNames,
	hertz: UnitNames,
	millimeter: UnitNames,
	centimeter: UnitNames,
	meter: UnitNames,
	kilometer: UnitNames,
	inch: UnitNames,
	foot: UnitNames,
	yard: UnitNames,
	mile: UnitNames,
	stud: UnitNames,
	squareMillimeter: UnitNames,
	squareCentimeter: UnitNames,
	squareMeter: UnitNames,
	hectare: UnitNames,
	squareKilometer: UnitNames,
	squareFoot: UnitNames,
	acre: UnitNames,
	milliliter: UnitNames,
	liter: UnitNames,
	cubicMeter: UnitNames,
	usFluidOunce: UnitNames,
	usGallon: UnitNames,
	imperialGallon: UnitNames,
	byte: UnitNames,
	kilobyte: UnitNames,
	megabyte: UnitNames,
	gigabyte: UnitNames,
	kibibyte: UnitNames,
	mebibyte: UnitNames,
	gibibyte: UnitNames,
	bytePerSecond: UnitNames,
	kilobytePerSecond: UnitNames,
	milligram: UnitNames,
	gram: UnitNames,
	kilogram: UnitNames,
	tonne: UnitNames,
	ounce: UnitNames,
	pound: UnitNames,
	stone: UnitNames,
	meterPerSecond: UnitNames,
	kilometerPerHour: UnitNames,
	milePerHour: UnitNames,
	knot: UnitNames,
	studPerSecond: UnitNames,
	meterPerSecondSquared: UnitNames,
	newton: UnitNames,
	kilonewton: UnitNames,
	meganewton: UnitNames,
	poundForce: UnitNames,
	joule: UnitNames,
	kilojoule: UnitNames,
	megajoule: UnitNames,
	kilowattHour: UnitNames,
	kilocalorie: UnitNames,
	watt: UnitNames,
	kilowatt: UnitNames,
	megawatt: UnitNames,
	pascal: UnitNames,
	kilopascal: UnitNames,
	megapascal: UnitNames,
	bar: UnitNames,
	poundForcePerSquareInch: UnitNames,
	kilogramPerCubicMeter: UnitNames,
	gramPerCubicCentimeter: UnitNames,
	kelvin: UnitNames,
	celsius: UnitNames,
	fahrenheit: UnitNames,
}

--[=[
	How to write something per a time unit, with `%s` for the numerator already written: `"%s/h"` and
	`"%s per hour"`.

	@interface PerNames
	.short string
	.long string
	@within MetricUnitLocalizationUtils
]=]
export type PerNames = { short: string, long: string }

--[=[
	[PerNames] for every time unit a rate can be written per.

	@interface PerStrings
	.second PerNames
	.minute PerNames
	.hour PerNames
	.day PerNames
	.week PerNames
	.month PerNames
	.year PerNames
	@within MetricUnitLocalizationUtils
]=]
export type PerStrings = {
	second: PerNames,
	minute: PerNames,
	hour: PerNames,
	day: PerNames,
	week: PerNames,
	month: PerNames,
	year: PerNames,
}

--[=[
	Unit phrases a caller passes to override a locale's, keyed by unit id: `{ kilometer = { short = "%s klicks" } }`.

	@type UnitStringOverrides { [string]: { short: UnitPhrase?, long: UnitPhrase? } }
	@within MetricUnitLocalizationUtils
]=]
export type UnitStringOverrides = { [string]: { short: UnitPhrase?, long: UnitPhrase? } }

--[=[
	Per phrases a caller passes to override a locale's, keyed by time unit id.

	@type PerStringOverrides { [string]: { short: string?, long: string? } }
	@within MetricUnitLocalizationUtils
]=]
export type PerStringOverrides = { [string]: { short: string?, long: string? } }

--[=[
	Everything one locale needs.

	@interface UnitLocale
	.units UnitStrings
	.per PerStrings
	@within MetricUnitLocalizationUtils
]=]
export type UnitLocale = {
	units: UnitStrings,
	per: PerStrings,
}

type Spelling = (string) -> string

local function american(text: string): string
	return text
end

-- Commonwealth English spells metre and litre, and calls a metric ton a tonne
local function commonwealth(text: string): string
	text = string.gsub(text, "metric tons?", { ["metric ton"] = "tonne", ["metric tons"] = "tonnes" })
	text = string.gsub(text, "meter", "metre")
	text = string.gsub(text, "liter", "litre")
	return text
end

function MetricUnitLocalizationUtils._english(
	spelling: Spelling,
	id: string,
	one: string,
	other: string,
	shortOne: string?,
	shortOther: string?
): UnitNames
	local unit = MetricUnitCatalog.getUnit(id)
	assert(unit, string.format("No unit %q", id))
	local short = "%s " .. unit.symbol
	return table.freeze({
		short = table.freeze({ one = shortOne or short, other = shortOther or short }),
		long = table.freeze({ one = "%s " .. spelling(one), other = "%s " .. spelling(other) }),
	})
end

function MetricUnitLocalizationUtils._englishUnits(spelling: Spelling): UnitStrings
	local function e(id: string, one: string, other: string, shortOne: string?, shortOther: string?): UnitNames
		return MetricUnitLocalizationUtils._english(spelling, id, one, other, shortOne, shortOther)
	end
	return table.freeze({
		microsecond = e("microsecond", "microsecond", "microseconds"),
		hertz = e("hertz", "hertz", "hertz"),
		millimeter = e("millimeter", "millimeter", "millimeters"),
		centimeter = e("centimeter", "centimeter", "centimeters"),
		meter = e("meter", "meter", "meters"),
		kilometer = e("kilometer", "kilometer", "kilometers"),
		inch = e("inch", "inch", "inches"),
		foot = e("foot", "foot", "feet"),
		yard = e("yard", "yard", "yards"),
		mile = e("mile", "mile", "miles"),
		stud = e("stud", "stud", "studs", "%s stud", "%s studs"),
		squareMillimeter = e("squareMillimeter", "square millimeter", "square millimeters"),
		squareCentimeter = e("squareCentimeter", "square centimeter", "square centimeters"),
		squareMeter = e("squareMeter", "square meter", "square meters"),
		hectare = e("hectare", "hectare", "hectares"),
		squareKilometer = e("squareKilometer", "square kilometer", "square kilometers"),
		squareFoot = e("squareFoot", "square foot", "square feet"),
		acre = e("acre", "acre", "acres"),
		milliliter = e("milliliter", "milliliter", "milliliters"),
		liter = e("liter", "liter", "liters"),
		cubicMeter = e("cubicMeter", "cubic meter", "cubic meters"),
		usFluidOunce = e("usFluidOunce", "US fluid ounce", "US fluid ounces"),
		usGallon = e("usGallon", "US gallon", "US gallons"),
		imperialGallon = e("imperialGallon", "imperial gallon", "imperial gallons"),
		byte = e("byte", "byte", "bytes"),
		kilobyte = e("kilobyte", "kilobyte", "kilobytes"),
		megabyte = e("megabyte", "megabyte", "megabytes"),
		gigabyte = e("gigabyte", "gigabyte", "gigabytes"),
		kibibyte = e("kibibyte", "kibibyte", "kibibytes"),
		mebibyte = e("mebibyte", "mebibyte", "mebibytes"),
		gibibyte = e("gibibyte", "gibibyte", "gibibytes"),
		bytePerSecond = e("bytePerSecond", "byte per second", "bytes per second"),
		kilobytePerSecond = e("kilobytePerSecond", "kilobyte per second", "kilobytes per second"),
		milligram = e("milligram", "milligram", "milligrams"),
		gram = e("gram", "gram", "grams"),
		kilogram = e("kilogram", "kilogram", "kilograms"),
		tonne = e("tonne", "metric ton", "metric tons"),
		ounce = e("ounce", "ounce", "ounces"),
		pound = e("pound", "pound", "pounds"),
		stone = e("stone", "stone", "stone"),
		meterPerSecond = e("meterPerSecond", "meter per second", "meters per second"),
		kilometerPerHour = e("kilometerPerHour", "kilometer per hour", "kilometers per hour"),
		milePerHour = e("milePerHour", "mile per hour", "miles per hour"),
		knot = e("knot", "knot", "knots"),
		studPerSecond = e("studPerSecond", "stud per second", "studs per second", "%s stud/s", "%s studs/s"),
		meterPerSecondSquared = e("meterPerSecondSquared", "meter per second squared", "meters per second squared"),
		newton = e("newton", "newton", "newtons"),
		kilonewton = e("kilonewton", "kilonewton", "kilonewtons"),
		meganewton = e("meganewton", "meganewton", "meganewtons"),
		poundForce = e("poundForce", "pound-force", "pounds-force"),
		joule = e("joule", "joule", "joules"),
		kilojoule = e("kilojoule", "kilojoule", "kilojoules"),
		megajoule = e("megajoule", "megajoule", "megajoules"),
		kilowattHour = e("kilowattHour", "kilowatt-hour", "kilowatt-hours"),
		kilocalorie = e("kilocalorie", "kilocalorie", "kilocalories"),
		watt = e("watt", "watt", "watts"),
		kilowatt = e("kilowatt", "kilowatt", "kilowatts"),
		megawatt = e("megawatt", "megawatt", "megawatts"),
		pascal = e("pascal", "pascal", "pascals"),
		kilopascal = e("kilopascal", "kilopascal", "kilopascals"),
		megapascal = e("megapascal", "megapascal", "megapascals"),
		bar = e("bar", "bar", "bars"),
		poundForcePerSquareInch = e(
			"poundForcePerSquareInch",
			"pound-force per square inch",
			"pounds-force per square inch"
		),
		kilogramPerCubicMeter = e("kilogramPerCubicMeter", "kilogram per cubic meter", "kilograms per cubic meter"),
		gramPerCubicCentimeter = e("gramPerCubicCentimeter", "gram per cubic centimeter", "grams per cubic centimeter"),
		kelvin = e("kelvin", "kelvin", "kelvins"),
		celsius = e("celsius", "degree Celsius", "degrees Celsius"),
		fahrenheit = e("fahrenheit", "degree Fahrenheit", "degrees Fahrenheit"),
	})
end

-- The SI symbols min, h and d are the same in every language; wk, mo and yr are English abbreviations
function MetricUnitLocalizationUtils._englishPerStrings(): PerStrings
	local function p(id: string, name: string): PerNames
		local unit = MetricUnitCatalog.getUnit(id)
		assert(unit, string.format("No unit %q", id))
		return table.freeze({ short = "%s/" .. unit.symbol, long = "%s per " .. name })
	end
	return table.freeze({
		second = p("second", "second"),
		minute = p("minute", "minute"),
		hour = p("hour", "hour"),
		day = p("day", "day"),
		week = p("week", "week"),
		month = p("month", "month"),
		year = p("year", "year"),
	})
end

local AMERICAN_ENGLISH: UnitLocale = table.freeze({
	units = MetricUnitLocalizationUtils._englishUnits(american),
	per = MetricUnitLocalizationUtils._englishPerStrings(),
})

local COMMONWEALTH_ENGLISH: UnitLocale = table.freeze({
	units = MetricUnitLocalizationUtils._englishUnits(commonwealth),
	per = MetricUnitLocalizationUtils._englishPerStrings(),
})

-- Bare `en` is American, the Roblox default; the Commonwealth regions that spell metre and litre share one table
local LOCALES: { [string]: UnitLocale } = table.freeze({
	en = AMERICAN_ENGLISH,
	["en-gb"] = COMMONWEALTH_ENGLISH,
	["en-au"] = COMMONWEALTH_ENGLISH,
	["en-ca"] = COMMONWEALTH_ENGLISH,
	["en-ie"] = COMMONWEALTH_ENGLISH,
	["en-nz"] = COMMONWEALTH_ENGLISH,
}) :: any

local warnedLocales: { [string]: boolean } = {}

--[=[
	Whether a locale has its own unit names, directly or through a locale of the same language.

	@param locale string?
	@return boolean
]=]
function MetricUnitLocalizationUtils.hasLocale(locale: string?): boolean
	return ResolveLocaleUtils.resolveClosestKey(locale or DEFAULT_LOCALE, LOCALES) ~= nil
end

--[=[
	Returns the read-only [UnitLocale] for a locale, defaulting to American English. Warns once per unknown locale.

	@param locale string?
	@return UnitLocale
]=]
function MetricUnitLocalizationUtils.getLocale(locale: string?): UnitLocale
	local key = ResolveLocaleUtils.resolveClosestKey(locale or DEFAULT_LOCALE, LOCALES)
	if key then
		return LOCALES[key]
	end

	local name = tostring(locale)
	if not warnedLocales[name] then
		warnedLocales[name] = true
		warn(
			string.format(
				"[MetricUnitLocalizationUtils] - No unit names for locale '%s', reverting to '%s' instead.",
				name,
				DEFAULT_LOCALE
			)
		)
	end
	return LOCALES[ResolveLocaleUtils.resolveClosestKey(DEFAULT_LOCALE, LOCALES) :: string]
end

--[=[
	Returns the read-only [UnitStrings] for a locale, defaulting to American English.

	@param locale string?
	@return UnitStrings
]=]
function MetricUnitLocalizationUtils.getUnitStringsForLocale(locale: string?): UnitStrings
	return MetricUnitLocalizationUtils.getLocale(locale).units
end

--[=[
	Returns the read-only [PerStrings] for a locale, defaulting to American English.

	@param locale string?
	@return PerStrings
]=]
function MetricUnitLocalizationUtils.getPerStringsForLocale(locale: string?): PerStrings
	return MetricUnitLocalizationUtils.getLocale(locale).per
end

return table.freeze(MetricUnitLocalizationUtils)
