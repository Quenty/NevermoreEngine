--!strict
--[=[
	Localizes ordinal numbers, for example `22nd` in English, `22e` in French, `22.` in German or
	`第22` in Chinese. Rules are keyed by language subtag and resolved through [ResolveLocaleUtils],
	so regional variants such as `en-gb` or `es-mx` land on their language's rule. Locales without
	a rule fall back to English with a warning.

	To add a language, add one entry to `ORDINAL_RULES`. Every field is required.

	@class NumberLocalizationOrdinalUtils
]=]

local require = require(script.Parent.loader).load(script)

local ResolveLocaleUtils = require("ResolveLocaleUtils")

local NumberLocalizationOrdinalUtils = {}

local DEFAULT_LOCALE = "en-us"

--[=[
	How a language writes an ordinal: `prefix .. number .. suffix(number)`.

	@interface OrdinalRule
	.prefix string
	.suffix (number) -> string
	@within NumberLocalizationOrdinalUtils
]=]
export type OrdinalRule = {
	prefix: string,
	suffix: (number) -> string,
}

function NumberLocalizationOrdinalUtils._constantSuffix(suffix: string): (number) -> string
	return function(_number: number): string
		return suffix
	end
end

function NumberLocalizationOrdinalUtils._englishSuffix(number: number): string
	local hundredRemainder = number % 100
	if hundredRemainder >= 11 and hundredRemainder <= 13 then
		return "th"
	end

	local tenRemainder = number % 10
	if tenRemainder == 1 then
		return "st"
	elseif tenRemainder == 2 then
		return "nd"
	elseif tenRemainder == 3 then
		return "rd"
	else
		return "th"
	end
end

function NumberLocalizationOrdinalUtils._frenchSuffix(number: number): string
	return if number == 1 then "er" else "e"
end

function NumberLocalizationOrdinalUtils._swedishSuffix(number: number): string
	local tenRemainder = number % 10
	local hundredRemainder = number % 100
	local isTeen = hundredRemainder >= 11 and hundredRemainder <= 12
	return if (tenRemainder == 1 or tenRemainder == 2) and not isTeen then ":a" else ":e"
end

local ORDINAL_INDICATOR = NumberLocalizationOrdinalUtils._constantSuffix("º")
local TRAILING_PERIOD = NumberLocalizationOrdinalUtils._constantSuffix(".")
local NO_SUFFIX = NumberLocalizationOrdinalUtils._constantSuffix("")

local ORDINAL_RULES: { [string]: OrdinalRule } = {
	en = { prefix = "", suffix = NumberLocalizationOrdinalUtils._englishSuffix },
	fr = { prefix = "", suffix = NumberLocalizationOrdinalUtils._frenchSuffix },
	sv = { prefix = "", suffix = NumberLocalizationOrdinalUtils._swedishSuffix },
	nl = { prefix = "", suffix = NumberLocalizationOrdinalUtils._constantSuffix("e") },

	-- Masculine ordinal indicator (1º, 2º)
	es = { prefix = "", suffix = ORDINAL_INDICATOR },
	pt = { prefix = "", suffix = ORDINAL_INDICATOR },
	it = { prefix = "", suffix = ORDINAL_INDICATOR },

	-- Trailing period (1., 2.)
	de = { prefix = "", suffix = TRAILING_PERIOD },
	pl = { prefix = "", suffix = TRAILING_PERIOD },
	tr = { prefix = "", suffix = TRAILING_PERIOD },
	fi = { prefix = "", suffix = TRAILING_PERIOD },
	da = { prefix = "", suffix = TRAILING_PERIOD },
	nb = { prefix = "", suffix = TRAILING_PERIOD },
	no = { prefix = "", suffix = TRAILING_PERIOD },
	cs = { prefix = "", suffix = TRAILING_PERIOD },
	hu = { prefix = "", suffix = TRAILING_PERIOD },

	-- Masculine digit ordinal (1-й, 22-й)
	ru = { prefix = "", suffix = NumberLocalizationOrdinalUtils._constantSuffix("-й") },

	-- Ordinal prefix (第22, 제22, ke-22, thứ 22, ที่ 22)
	zh = { prefix = "第", suffix = NO_SUFFIX },
	ja = { prefix = "第", suffix = NO_SUFFIX },
	ko = { prefix = "제", suffix = NO_SUFFIX },
	id = { prefix = "ke-", suffix = NO_SUFFIX },
	vi = { prefix = "thứ ", suffix = NO_SUFFIX },
	th = { prefix = "ที่ ", suffix = NO_SUFFIX },

	-- Arabic writes digit ordinals as the bare number
	ar = { prefix = "", suffix = NO_SUFFIX },
}

for _, rule in pairs(ORDINAL_RULES) do
	table.freeze(rule)
end

function NumberLocalizationOrdinalUtils._resolveRuleOrDefault(locale: string?): OrdinalRule
	local key = ResolveLocaleUtils.resolveClosestKey(locale, ORDINAL_RULES)
	if key then
		return ORDINAL_RULES[key]
	end

	warn(
		string.format(
			"[NumberLocalizationOrdinalUtils] - No ordinal rule for locale '%s', reverting to '%s' instead.",
			tostring(locale),
			DEFAULT_LOCALE
		)
	)
	return ORDINAL_RULES[ResolveLocaleUtils.resolveClosestKey(DEFAULT_LOCALE, ORDINAL_RULES) :: string]
end

--[=[
	Returns the localized ordinal form of a whole number.

	```lua
	print(NumberLocalizationOrdinalUtils.localize(22, "en-us")) --> 22nd
	print(NumberLocalizationOrdinalUtils.localize(1, "fr-fr")) --> 1er
	print(NumberLocalizationOrdinalUtils.localize(22, "zh-cn")) --> 第22
	```
]=]
function NumberLocalizationOrdinalUtils.localize(number: number, locale: string): string
	assert(type(number) == "number", "Bad number")

	local rule = NumberLocalizationOrdinalUtils._resolveRuleOrDefault(locale)
	return rule.prefix .. tostring(number) .. rule.suffix(number)
end

--[=[
	Returns only the part of the localized ordinal that follows the number, for example `nd` for
	22 in English or `.` in German. Languages that mark ordinals with a prefix (Chinese, Japanese,
	Korean, Indonesian, Vietnamese, Thai) have an empty suffix; use
	[NumberLocalizationOrdinalUtils.localize] for the whole form.
]=]
function NumberLocalizationOrdinalUtils.getSuffix(number: number, locale: string): string
	assert(type(number) == "number", "Bad number")

	return NumberLocalizationOrdinalUtils._resolveRuleOrDefault(locale).suffix(number)
end

return NumberLocalizationOrdinalUtils
