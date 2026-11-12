--!strict
--[=[
	English unit names for [MetricUnitFormatUtils] when no translator is given. They need no translator, so specs,
	servers and anything formatting before a translator loads always get readable text. Translated names stream to clients through [MetricUnitTranslator], a
	`JSONTranslator` holding the same keys.

	Lookups resolve through [ResolveLocaleUtils], so `en-us` lands on American English and `en-au` on Commonwealth
	English. Without a translator, short phrases are the symbols in [MetricUnitDefinitions]; with one, they are the player's language's
	(`5 км`, `5公里`). A no-break space joins a number to its unit either way.

	@class MetricUnitFallbackStrings
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local ResolveLocaleUtils = require("ResolveLocaleUtils")

local MetricUnitFallbackStrings = {}

local DEFAULT_LOCALE = "en-us"

--[=[
	A unit phrase with `%s` for the already formatted number: a singular and plural pair, or a function of the
	rounded amount and the formatted number for languages with more plural forms.

	@type UnitPhrase { one: string, other: string } | (amount: number, numberText: string) -> string
	@within MetricUnitFallbackStrings
]=]
export type UnitPhrase = { one: string, other: string } | (number, string) -> string

--[=[
	The short and long phrase for one unit, such as `"%s km"` and `"%s kilometers"`.

	@interface UnitNames
	.short UnitPhrase
	.long UnitPhrase
	@within MetricUnitFallbackStrings
]=]
export type UnitNames = { short: UnitPhrase, long: UnitPhrase }

--[=[
	[UnitNames] for every unit written by name, keyed by unit id: every unit [MetricUnitDefinitions] gives `names`. Time
	units are written with [TimeLocalizationUtils]' duration words instead, and bare rates with [PerStrings].

	@type UnitStrings { [UnitId]: UnitNames }
	@within MetricUnitFallbackStrings
]=]
export type UnitStrings = { [string]: UnitNames }

--[=[
	How to write something per a time unit, with `%s` for the numerator already written: `"%s/h"` and
	`"%s per hour"`.

	@interface PerNames
	.short string
	.long string
	@within MetricUnitFallbackStrings
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
	@within MetricUnitFallbackStrings
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
	@within MetricUnitFallbackStrings
]=]
export type UnitStringOverrides = { [string]: { short: UnitPhrase?, long: UnitPhrase? } }

--[=[
	Per phrases a caller passes to override a locale's, keyed by time unit id.

	@type PerStringOverrides { [string]: { short: string?, long: string? } }
	@within MetricUnitFallbackStrings
]=]
export type PerStringOverrides = { [string]: { short: string?, long: string? } }

--[=[
	Everything one locale needs.

	@interface UnitLocale
	.units UnitStrings
	.per PerStrings
	@within MetricUnitFallbackStrings
]=]
export type UnitLocale = {
	units: UnitStrings,
	per: PerStrings,
}

-- U+00A0, not CLDR's narrow U+202F: create.roblox.com does not document how TextLabels render U+202F
local NO_BREAK_SPACE = "\u{00A0}"
MetricUnitFallbackStrings.NO_BREAK_SPACE = NO_BREAK_SPACE

local function withNoBreakSpaceAfterNumber(template: string): string
	return (string.gsub(template, "^%%s ", "%%s" .. NO_BREAK_SPACE))
end

type Spelling = (string) -> string

local function american(text: string): string
	return text
end

--[=[
	`text` in Commonwealth English spelling: metre for meter, litre for liter, tonne for metric ton.

	@param text string
	@return string
]=]
function MetricUnitFallbackStrings.toCommonwealthSpelling(text: string): string
	text = string.gsub(text, "metric tons?", { ["metric ton"] = "tonne", ["metric tons"] = "tonnes" })
	text = string.gsub(text, "meter", "metre")
	text = string.gsub(text, "liter", "litre")
	return text
end

function MetricUnitFallbackStrings._lazyEnglishUnits(spelling: Spelling): UnitStrings
	return setmetatable({}, {
		__index = function(self, id: string): UnitNames?
			local unit = MetricUnitDefinitions.getUnit(id)
			if not (unit and unit.names) then
				return nil
			end
			local names = MetricUnitFallbackStrings._englishNamesOf(unit, spelling)
			rawset(self, id, names)
			return names
		end,
	}) :: any
end

function MetricUnitFallbackStrings._englishNamesOf(
	unit: MetricUnitDefinitions.UnitDefinition,
	spelling: Spelling
): UnitNames
	local short = "%s" .. NO_BREAK_SPACE .. unit.symbol
	local templates = unit.shortTemplates
	local names = unit.names or { one = unit.symbol, other = unit.symbol }
	return table.freeze({
		short = table.freeze({
			one = if templates then withNoBreakSpaceAfterNumber(templates.one) else short,
			other = if templates then withNoBreakSpaceAfterNumber(templates.other) else short,
		}),
		long = table.freeze({
			one = "%s" .. NO_BREAK_SPACE .. spelling(names.one),
			other = "%s" .. NO_BREAK_SPACE .. spelling(names.other),
		}),
	})
end

local PER_TIME_UNIT_IDS: { [string]: boolean } =
	table.freeze({ second = true, minute = true, hour = true, day = true, week = true, month = true, year = true })

function MetricUnitFallbackStrings._lazyEnglishPerStrings(): PerStrings
	return setmetatable({}, {
		__index = function(self, id: string): PerNames?
			local unit = if PER_TIME_UNIT_IDS[id] then MetricUnitDefinitions.getUnit(id) else nil
			if not unit then
				return nil
			end
			local names = table.freeze({ short = "%s/" .. unit.symbol, long = "%s per " .. id })
			rawset(self, id, names)
			return names
		end,
	}) :: any
end

local AMERICAN_ENGLISH: UnitLocale = table.freeze({
	units = MetricUnitFallbackStrings._lazyEnglishUnits(american),
	per = MetricUnitFallbackStrings._lazyEnglishPerStrings(),
})

local COMMONWEALTH_ENGLISH: UnitLocale = table.freeze({
	units = MetricUnitFallbackStrings._lazyEnglishUnits(MetricUnitFallbackStrings.toCommonwealthSpelling),
	per = MetricUnitFallbackStrings._lazyEnglishPerStrings(),
})

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
	Whether a locale has its own unit names here, directly or through a locale of the same language.

	@param locale string?
	@return boolean
]=]
function MetricUnitFallbackStrings.hasLocale(locale: string?): boolean
	return ResolveLocaleUtils.resolveClosestKey(locale or DEFAULT_LOCALE, LOCALES) ~= nil
end

--[=[
	Returns the read-only [UnitLocale] for a locale, defaulting to American English. Warns once per unknown locale.

	@param locale string?
	@return UnitLocale
]=]
function MetricUnitFallbackStrings.getLocale(locale: string?): UnitLocale
	local key = ResolveLocaleUtils.resolveClosestKey(locale or DEFAULT_LOCALE, LOCALES)
	if key then
		return LOCALES[key]
	end

	local name = tostring(locale)
	if not warnedLocales[name] then
		warnedLocales[name] = true
		warn(
			string.format(
				"[MetricUnitFallbackStrings] - No unit names for locale '%s', reverting to '%s' instead.",
				name,
				DEFAULT_LOCALE
			)
		)
	end
	return LOCALES[ResolveLocaleUtils.resolveClosestKey(DEFAULT_LOCALE, LOCALES) :: string]
end

--[=[
	The [UnitNames] of `unit` in a locale: the locale's own, or, for a unit a game's own [MetricUnitSystem] declares,
	its English names and symbol from its definition.

	@param locale string?
	@param unit UnitDefinition
	@return UnitNames
]=]
function MetricUnitFallbackStrings.getUnitNames(locale: string?, unit: MetricUnitDefinitions.UnitDefinition): UnitNames
	local unitLocale = MetricUnitFallbackStrings.getLocale(locale)
	local names = unitLocale.units[unit.id]
	if names then
		return names
	end
	local spelling = if unitLocale == COMMONWEALTH_ENGLISH
		then MetricUnitFallbackStrings.toCommonwealthSpelling
		else american
	return MetricUnitFallbackStrings._englishNamesOf(unit, spelling)
end

--[=[
	Returns the read-only [UnitStrings] for a locale, defaulting to American English. Each unit's names are built the
	first time they are read.

	@param locale string?
	@return UnitStrings
]=]
function MetricUnitFallbackStrings.getUnitStringsForLocale(locale: string?): UnitStrings
	return MetricUnitFallbackStrings.getLocale(locale).units
end

--[=[
	Returns the read-only [PerStrings] for a locale, defaulting to American English.

	@param locale string?
	@return PerStrings
]=]
function MetricUnitFallbackStrings.getPerStringsForLocale(locale: string?): PerStrings
	return MetricUnitFallbackStrings.getLocale(locale).per
end

return table.freeze(MetricUnitFallbackStrings)
