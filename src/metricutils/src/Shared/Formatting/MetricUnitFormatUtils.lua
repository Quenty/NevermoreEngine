--!strict
--[=[
	Writes measurements for people, in the style of JavaScript's `Intl.NumberFormat` with `style: "unit"`: a
	localized number, then the unit's symbol or name. The unit is picked to suit the value's size unless one is
	given, so 1,500 N is `1.5 kN`. Takes a [MetricUnit] or its plain [MetricUnitData].

	Numbers go through [NumberLocalizationUtils], so digit grouping and the decimal mark follow the locale. Unit
	names come from [MetricUnitFallbackStrings], and duration words from [TimeLocalizationUtils].

	A duration is broken into years, months, days, hours, minutes and seconds with [MetricUnit]'s own averaged year
	and month (a Julian year, and a twelfth of it), not `@quenty/time`'s 365 and 30 days, so `MetricUnit.years(1)`
	reads `1 year` and `MetricUnit.months(1)` reads `1 month`. Only `@quenty/time`'s words are used. For a clock-style
	`h:mm:ss`, or calendar months, hand exact seconds to `TimeDurationUtils` or `Time` yourself.

	```lua
	MetricUnitFormatUtils.format(MetricUnit.meters(1500)) --> 1.5 km
	MetricUnitFormatUtils.format(MetricUnit.meters(1500), { unitDisplay = "long" }) --> 1.5 kilometers
	MetricUnitFormatUtils.format(MetricUnit.meters(1500):ToUSCustomary()) --> 4,921.26 ft
	MetricUnitFormatUtils.format({ amount = 1234.5, dimensions = { length = 1 } }, { unit = "meter", locale = "de-de" }) --> 1 234,5 m
	MetricUnitFormatUtils.format(MetricUnit.minutes(90)) --> 1 hour, 30 minutes
	MetricUnitFormatUtils.formatUnit("kilowattHour", 3) --> 3 kWh
	```

	@class MetricUnitFormatUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")
local MetricUnitDisplayUnitUtils = require("MetricUnitDisplayUnitUtils")
local MetricUnitFallbackStrings = require("MetricUnitFallbackStrings")
local MetricUnitKinds = require("MetricUnitKinds")
local MetricUnitSystem = require("MetricUnitSystem")
local NumberLocalizationUtils = require("NumberLocalizationUtils")
local PluralCategoryUtils = require("PluralCategoryUtils")
local Time = require("Time")
local TimeDurationUtils = require("TimeDurationUtils")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local MetricUnitFormatUtils = {}

--[=[
	The no-break space (U+00A0) that joins a number to its unit, so a line never wraps between them.

	@prop NO_BREAK_SPACE string
	@within MetricUnitFormatUtils
]=]
MetricUnitFormatUtils.NO_BREAK_SPACE = MetricUnitFallbackStrings.NO_BREAK_SPACE

local DEFAULT_LOCALE = "en-us"
local DEFAULT_MAXIMUM_FRACTION_DIGITS = 3
local DEFAULT_DURATION_PARTS = 2
local LARGEST_GROUPED_INTEGER = 1e15
local DECIMAL_SEPARATOR_PROBE = 0.5
local ENGLISH_PLURAL_RULES = "en"
local YEAR_OR_MONTH_CLOCK_TOKENS = "[yM]"
-- Keeps twelve averaged months, summed in floating point, a whole year
local WHOLE_UNIT_TOLERANCE = 1e-9
local NUMBER_MARK = "\u{E000}"
local UNIT_MARK = "\u{E001}"

--[=[
	`"short"` writes the unit's symbol (`5 km`), `"long"` its name (`5 kilometers`).

	@type UnitDisplay "short" | "long"
	@within MetricUnitFormatUtils
]=]
export type UnitDisplay = "short" | "long"

--[=[
	A measurement as plain data, for saves and for formatting without a [MetricUnit]: its amount in SI base units,
	its exponents, and whether it is absolute. [MetricUnit.toData] and [MetricUnit.fromData] convert to and from it.

	@interface MetricUnitData
	.amount number
	.dimensions { [string]: number }
	.absolute boolean?
	@within MetricUnitFormatUtils
]=]
export type MetricUnitData = {
	amount: number,
	dimensions: { [string]: number },
	absolute: boolean?,
}

--[=[
	How a duration is written: in words through `@quenty/time`'s duration phrases, or as a clock.

	@type DurationStyle "words" | "clock"
	@within MetricUnitFormatUtils
]=]
export type DurationStyle = "words" | "clock"

--[=[
	What the formatter needs of [MetricUnitTranslator]: a `JSONTranslator`'s `FormatByKey`, `GetLocaleId` and,
	for [RxMetricUnitFormatUtils.observeFormat], `ObserveFormatByKey`.

	@interface MetricUnitTranslatorLike
	.FormatByKey (self, key: string, args: { [string]: any }?) -> string
	.GetLocaleId (self) -> string
	.ObserveFormatByKey (self, key: string, args: { [string]: any }?) -> Observable<string>
	@within MetricUnitFormatUtils
]=]
export type MetricUnitTranslatorLike = {
	FormatByKey: (any, string, { [string]: any }?) -> string,
	GetLocaleId: (any) -> string,
	ObserveFormatByKey: (any, string, { [string]: any }?) -> any,
}

--[=[
	Options for [MetricUnitFormatUtils.format], modelled on `Intl.NumberFormat`.

	@interface MetricUnitFormatOptions
	.locale string? -- Picks the number format and unit names, defaults to `en-us`
	.unitDisplay UnitDisplay? -- `short` symbols (the default) or `long` names
	.unit UnitLike? -- Always write this unit; for a rate, the whole rate's (`kilometerPerHour`, `perHour`) or the numerator's (`kilometer`)
	.perUnit TimeUnit? -- Always write a rate per this time unit, such as `"hour"` or `"h"`
	.autoUnit boolean? -- Pick the unit that suits the size (the default), or always write the SI base unit
	.minimumFractionDigits number? -- Pad with zeros to at least this many decimals, defaults to 0
	.maximumFractionDigits number? -- Round to at most this many decimals, defaults to 3
	.maximumSignificantDigits number? -- Round to this many significant digits instead of fraction digits
	.useGrouping boolean? -- Group thousands for the locale, defaults to true
	.strings UnitStringOverrides? -- Overrides a unit's phrase, e.g. `{ kilometer = { short = "%s klicks" } }`
	.perStrings PerStringOverrides? -- Overrides a per phrase, e.g. `{ hour = { short = "%s an hour" } }`
	.durationStrings DurationStringOverrides? -- Overrides a duration word, as in `TimeDurationUtils`
	.maxParts number? -- How many non-zero units a duration is written in, largest first, defaults to 2
	.separator string? -- Between the parts of a duration, defaults to `, `
	.durationStyle DurationStyle? -- `words` (the default, `1 hour, 30 minutes`) or `clock` (`1:30:00`, or `1:30` under an hour)
	.durationTemplate string? -- A `TimeDurationUtils.format` template such as `hh:mm:ss`; years and months are refused
	.translator MetricUnitTranslatorLike? -- [MetricUnitTranslator], for long names in the player's language
	@within MetricUnitFormatUtils
]=]
export type MetricUnitFormatOptions = {
	locale: string?,
	unitDisplay: UnitDisplay?,
	unit: MetricUnitDefinitions.UnitLike?,
	perUnit: Time.TimeUnit?,
	autoUnit: boolean?,
	minimumFractionDigits: number?,
	maximumFractionDigits: number?,
	maximumSignificantDigits: number?,
	useGrouping: boolean?,
	strings: MetricUnitFallbackStrings.UnitStringOverrides?,
	perStrings: MetricUnitFallbackStrings.PerStringOverrides?,
	durationStrings: TimeLocalizationUtils.DurationStringOverrides?,
	maxParts: number?,
	separator: string?,
	durationStyle: DurationStyle?,
	durationTemplate: string?,
	translator: MetricUnitTranslatorLike?,
	_system: MetricUnitSystem.MetricUnitSystem?,
}

type UnitDefinition = MetricUnitDefinitions.UnitDefinition
type DurationUnit = { field: string, factor: number }

local DURATION_FIELDS_LARGEST_FIRST: { { field: string, unitId: string } } = table.freeze({
	{ field = "years", unitId = "year" },
	{ field = "months", unitId = "month" },
	{ field = "days", unitId = "day" },
	{ field = "hours", unitId = "hour" },
	{ field = "minutes", unitId = "minute" },
	{ field = "seconds", unitId = "second" },
	{ field = "milliseconds", unitId = "millisecond" },
})
local durationUnitsLargestFirst: { DurationUnit }? = nil

local TIME_LOCALIZATION_FIELD_BY_UNIT_ID: { [string]: string } = {
	millisecond = "milliseconds",
	second = "seconds",
	minute = "minutes",
	hour = "hours",
	day = "days",
	week = "weeks",
	month = "months",
	year = "years",
}

local SUPERSCRIPTS: { [number]: string } = { [2] = "²", [3] = "³" }

local decimalSeparators: { [string]: string } = {}

--[=[
	Writes a measurement for the locale in a unit that suits its size, or the one `options.unit` names. Durations are
	broken into parts with localized words, temperatures keep whether they are absolute (`5 °C`) or a difference
	(`5 K`), and a rate is written per the shortest time unit it fills at least once (`1.6 MB/s`).

	A value is written in the system of the unit it was made from, so `MetricUnit.new(5, "mile")` writes miles and
	`MetricUnit.kilometers(8)` kilometres. Convert it to write another ([MetricUnit.ToMetric],
	[MetricUnit.ToImperial]), or use [MetricUnitSystem.Format]. The locale never chooses a measurement system.

	```lua
	local length = MetricUnit.meters(2500)
	MetricUnitFormatUtils.format(length) --> 2.5 km
	MetricUnitFormatUtils.format(length, { unit = "meter" }) --> 2,500 m
	MetricUnitFormatUtils.format(length, { unit = "stud" }) --> 8,928.571 studs
	MetricUnitFormatUtils.format(length, { unitDisplay = "long", locale = "en-gb" }) --> 2.5 kilometres
	MetricUnitFormatUtils.format(length, { maximumSignificantDigits = 1 }) --> 3 km
	```

	@param value MetricUnit | MetricUnitData
	@param options MetricUnitFormatOptions?
	@return string
]=]
function MetricUnitFormatUtils.format(
	-- any: MetricUnit requires this module, so its type cannot be named here; _readValue checks it at runtime
	value: any,
	options: MetricUnitFormatOptions?
): string
	local amount, dimensions, absolute, displaySystem, displayUnit = MetricUnitFormatUtils._readValue(value)
	local resolved = MetricUnitFormatUtils._resolveOptionsWithValuePreference(options, displaySystem, displayUnit)

	if MetricUnitDimensionUtils.equal(dimensions, MetricUnitKinds.TIME) then
		return MetricUnitFormatUtils._formatDuration(amount, resolved)
	end
	return MetricUnitFormatUtils._formatRelative(amount, dimensions, resolved, resolved.unit, absolute)
end

function MetricUnitFormatUtils._formatInSystem(
	value: any,
	system: MetricUnitSystem.MetricUnitSystem,
	options: MetricUnitFormatOptions?
): string
	local resolved: MetricUnitFormatOptions = if options then table.clone(options) else {}
	resolved._system = system
	return MetricUnitFormatUtils.format(value, resolved)
end

--[=[
	Writes `amount` of the unit `unit`, as [MetricUnitFormatUtils.format] would, without picking another unit. A
	temperature is absolute on its own scale, so `formatUnit("celsius", 20)` is `20 °C`.

	```lua
	MetricUnitFormatUtils.formatUnit("kilometerPerHour", 90) --> 90 km/h
	MetricUnitFormatUtils.formatUnit("liter", 1, { unitDisplay = "long" }) --> 1 liter
	MetricUnitFormatUtils.formatUnit("hours", 1.5) --> 1.5 hours
	```

	@param unit UnitLike
	@param amount number -- in `unit`
	@param options MetricUnitFormatOptions?
	@return string
]=]
function MetricUnitFormatUtils.formatUnit(
	unit: MetricUnitDefinitions.UnitLike,
	amount: number,
	options: MetricUnitFormatOptions?
): string
	assert(type(amount) == "number", "Bad amount")
	local resolved = MetricUnitFormatUtils._resolveOptionsWithValuePreference(options, nil, nil)
	local definition = MetricUnitFormatUtils._getUnit(resolved, unit)
	assert(definition, string.format("No unit %q", tostring(unit)))

	if definition.duration then
		return MetricUnitFormatUtils._durationUnitPhrase(definition, amount, resolved)
	elseif definition.per then
		local per = MetricUnitFormatUtils._perUnit(definition.per)
		return MetricUnitFormatUtils._perPhrase(per, MetricUnitFormatUtils._formatNumber(amount, resolved), resolved)
	end
	return MetricUnitFormatUtils._unitPhrase(definition, amount, resolved)
end

--[=[
	Writes a plain number for the locale: grouped thousands, the locale's decimal mark, and the digit options of
	[MetricUnitFormatOptions].

	```lua
	MetricUnitFormatUtils.formatNumber(1234.5678) --> 1,234.568
	MetricUnitFormatUtils.formatNumber(1234.5, { locale = "de-de" }) --> 1 234,5
	MetricUnitFormatUtils.formatNumber(2, { minimumFractionDigits = 2 }) --> 2.00
	```

	@param value number
	@param options MetricUnitFormatOptions?
	@return string
]=]
function MetricUnitFormatUtils.formatNumber(value: number, options: MetricUnitFormatOptions?): string
	assert(type(value) == "number", "Bad value")
	local text = MetricUnitFormatUtils._formatNumber(value, options or {})
	return text
end

function MetricUnitFormatUtils._readValue(value: any): (
	number,
	MetricUnitDimensionUtils.Dimensions,
	boolean,
	MetricUnitSystem.MetricUnitSystem?,
	UnitDefinition?
)
	assert(type(value) == "table", "Bad value")
	if type(value.amount) == "number" then
		assert(MetricUnitDimensionUtils.isDimensions(value.dimensions), "Bad dimensions")
		return value.amount, value.dimensions, value.absolute == true, nil, nil
	end
	assert(value.ClassName == "MetricUnit", "Bad value, expected a MetricUnit or MetricUnitData")
	return value:GetBaseAmount(),
		value:GetDimensions(),
		value:IsAbsolute(),
		value:GetDisplaySystem(),
		value:GetDisplayUnit()
end

function MetricUnitFormatUtils._resolveOptionsWithValuePreference(
	options: MetricUnitFormatOptions?,
	displaySystem: MetricUnitSystem.MetricUnitSystem?,
	displayUnit: UnitDefinition?
): MetricUnitFormatOptions
	local resolved: MetricUnitFormatOptions = if options then table.clone(options) else {}
	if resolved.locale == nil and resolved.translator then
		resolved.locale = resolved.translator:GetLocaleId()
	end
	if resolved._system == nil then
		resolved._system = displaySystem
	end
	if resolved.unit == nil and displayUnit then
		resolved.unit = displayUnit
	end
	return resolved
end

function MetricUnitFormatUtils._getUnit(
	options: MetricUnitFormatOptions,
	unit: string | UnitDefinition
): UnitDefinition?
	local system = options._system
	return if system then system:GetUnit(unit) else MetricUnitDefinitions.getUnit(unit)
end

function MetricUnitFormatUtils._tryTranslate(
	options: MetricUnitFormatOptions,
	keys: { string },
	args: { [string]: string }
): string?
	local translator = options.translator
	if not translator then
		return nil
	end
	for _, key in keys do
		local ok, text = pcall(translator.FormatByKey, translator, key, args)
		if ok and type(text) == "string" and text ~= key then
			return text
		end
	end
	return nil
end

function MetricUnitFormatUtils._formatNumber(value: number, options: MetricUnitFormatOptions): (string, number, string)
	if value ~= value or value == math.huge or value == -math.huge then
		local noFractionDigits = ""
		return tostring(value), value, noFractionDigits
	end

	local locale = options.locale or DEFAULT_LOCALE
	local minimumFractionDigits = options.minimumFractionDigits or 0

	local rounded, decimals
	if options.maximumSignificantDigits then
		local significant = options.maximumSignificantDigits
		if value == 0 then
			rounded, decimals = 0, 0
		else
			local places = significant - (math.floor(math.log10(math.abs(value))) + 1)
			rounded = MetricUnitFormatUtils._roundHalfAwayFromZero(value, places)
			decimals = math.max(0, places)
		end
	else
		decimals = options.maximumFractionDigits or DEFAULT_MAXIMUM_FRACTION_DIGITS
		rounded = MetricUnitFormatUtils._roundHalfAwayFromZero(value, decimals)
	end
	decimals = math.max(decimals, minimumFractionDigits)

	local digits = string.format("%." .. tostring(decimals) .. "f", math.abs(rounded))
	local integerPart, shownFractionDigits = string.match(digits, "^(%d+)%.?(%d*)$")
	assert(integerPart and shownFractionDigits, "Bad number")
	while #shownFractionDigits > minimumFractionDigits and string.sub(shownFractionDigits, -1) == "0" do
		shownFractionDigits = string.sub(shownFractionDigits, 1, -2)
	end

	local integerValue = tonumber(integerPart) :: number
	if options.useGrouping ~= false and integerValue < LARGEST_GROUPED_INTEGER then
		integerPart = NumberLocalizationUtils.localize(integerValue, locale)
	end

	local text = (if rounded < 0 then "-" else "") .. integerPart
	if #shownFractionDigits > 0 then
		text ..= MetricUnitFormatUtils.getDecimalSeparator(locale) .. shownFractionDigits
	end
	return text, rounded, shownFractionDigits
end

function MetricUnitFormatUtils._roundHalfAwayFromZero(value: number, decimalPlacesOrNegativeForTens: number): number
	local factor = 10 ^ decimalPlacesOrNegativeForTens
	local rounded = math.floor(math.abs(value) * factor + 0.5) / factor
	return if value < 0 and rounded ~= 0 then -rounded else rounded
end

--[=[
	The decimal mark `locale` writes numbers with, such as `"."` or `","`.

	@param locale string
	@return string
]=]
function MetricUnitFormatUtils.getDecimalSeparator(locale: string): string
	local cached = decimalSeparators[locale]
	if cached then
		return cached
	end

	local separator = MetricUnitFormatUtils._readDecimalSeparatorFromAbbreviate(locale)
	decimalSeparators[locale] = separator
	return separator
end

-- NumberLocalizationUtils.localize always writes "." as the decimal mark; abbreviate writes the locale's
function MetricUnitFormatUtils._readDecimalSeparatorFromAbbreviate(locale: string): string
	local probe = NumberLocalizationUtils.abbreviate(DECIMAL_SEPARATOR_PROBE, locale, nil, 1)
	return string.match(probe, "^0(.-)5$") or "."
end

function MetricUnitFormatUtils._getUnitLocale(options: MetricUnitFormatOptions): MetricUnitFallbackStrings.UnitLocale
	return MetricUnitFallbackStrings.getLocale(MetricUnitFormatUtils._fallbackStringsLocale(options))
end

function MetricUnitFormatUtils._fallbackStringsLocale(options: MetricUnitFormatOptions): string?
	local writesSymbolsThatAreTheSameInEveryLocale = options.unitDisplay ~= "long"
	if writesSymbolsThatAreTheSameInEveryLocale and not MetricUnitFallbackStrings.hasLocale(options.locale) then
		return DEFAULT_LOCALE
	end
	return options.locale
end

function MetricUnitFormatUtils._pickPluralTemplate(
	phrase: { one: string, other: string },
	pluralRulesLocale: string?,
	rounded: number,
	fractionDigits: string
): string
	local category = PluralCategoryUtils.getPluralCategory(pluralRulesLocale, rounded, fractionDigits)
	return if category == "one" then phrase.one else phrase.other
end

function MetricUnitFormatUtils._applyUnitPhrase(
	phrase: MetricUnitFallbackStrings.UnitPhrase,
	pluralRulesLocale: string?,
	rounded: number,
	numberText: string,
	fraction: string
): string
	if type(phrase) == "function" then
		return phrase(rounded, numberText)
	end
	local template = MetricUnitFormatUtils._pickPluralTemplate(phrase, pluralRulesLocale, rounded, fraction)
	return (string.gsub(template, "%%s", function()
		return numberText
	end))
end

function MetricUnitFormatUtils._unitPhrase(
	definition: UnitDefinition,
	amount: number,
	options: MetricUnitFormatOptions,
	display: UnitDisplay?
): string
	local numberText, rounded, fraction = MetricUnitFormatUtils._formatNumber(amount, options)
	local resolvedDisplay: UnitDisplay = display or options.unitDisplay or "short"

	local override = if options.strings then options.strings[definition.id] else nil
	local phrase = if override then (override :: any)[resolvedDisplay] else nil
	if phrase == nil and options.translator then
		local category = PluralCategoryUtils.getPluralCategory(options.locale, rounded, fraction)
		local keys = {
			MetricUnitFormatUtils._unitTranslationKey(definition.id, resolvedDisplay, category),
			MetricUnitFormatUtils._unitTranslationKey(definition.id, resolvedDisplay, "other"),
		}
		local translated = MetricUnitFormatUtils._tryTranslate(options, keys, { n = numberText })
			or MetricUnitFormatUtils._translatePrefixed(options, definition, resolvedDisplay, category, numberText)
		if translated then
			return translated
		end
	end
	local pluralRulesLocale = options.locale
	if phrase == nil then
		local locale = MetricUnitFormatUtils._fallbackStringsLocale(options)
		phrase = (MetricUnitFallbackStrings.getUnitNames(locale, definition) :: any)[resolvedDisplay]
		pluralRulesLocale = ENGLISH_PLURAL_RULES
	end

	return MetricUnitFormatUtils._applyUnitPhrase(phrase, pluralRulesLocale, rounded, numberText, fraction)
end

function MetricUnitFormatUtils._translatePrefixed(
	options: MetricUnitFormatOptions,
	definition: UnitDefinition,
	display: UnitDisplay,
	category: string,
	numberText: string
): string?
	local prefix = definition.prefix
	if not prefix then
		return nil
	end
	local baseText = MetricUnitFormatUtils._tryTranslate(options, {
		MetricUnitFormatUtils._unitTranslationKey(prefix.base, display, category),
		MetricUnitFormatUtils._unitTranslationKey(prefix.base, display, "other"),
	}, { n = NUMBER_MARK })
	local prefixPattern = MetricUnitFormatUtils._tryTranslate(
		options,
		{ "prefixes." .. prefix.name .. "." .. display },
		{ unit = UNIT_MARK }
	)
	if not (baseText and prefixPattern) then
		return nil
	end

	local unitText = MetricUnitFormatUtils._withoutNumber(baseText)
	local start, finish = string.find(baseText, unitText, 1, true)
	if unitText == "" or not start then
		return nil
	end
	local prefixIsACapitalizedWordBeforeTheUnit = display == "long"
		and string.match(prefixPattern, "^%u") ~= nil
		and string.sub(prefixPattern, -#UNIT_MARK) == UNIT_MARK
	local unitInPrefix = if prefixIsACapitalizedWordBeforeTheUnit
		then string.lower(string.sub(unitText, 1, 1)) .. string.sub(unitText, 2)
		else unitText
	local prefixedUnit = string.gsub(prefixPattern, UNIT_MARK, function()
		return unitInPrefix
	end)
	local text = string.sub(baseText, 1, start - 1) .. prefixedUnit .. string.sub(baseText, (finish :: number) + 1)
	return (string.gsub(text, NUMBER_MARK, function()
		return numberText
	end))
end

function MetricUnitFormatUtils._withoutNumber(text: string): string
	local unitText = string.gsub(text, NUMBER_MARK, "")
	for _, space in { " ", MetricUnitFormatUtils.NO_BREAK_SPACE } do
		while string.sub(unitText, 1, #space) == space do
			unitText = string.sub(unitText, #space + 1)
		end
		while #unitText >= #space and string.sub(unitText, -#space) == space do
			unitText = string.sub(unitText, 1, -#space - 1)
		end
	end
	return unitText
end

function MetricUnitFormatUtils._durationUnitsLargestFirst(): { DurationUnit }
	local found = durationUnitsLargestFirst
	if found then
		return found
	end
	local units: { DurationUnit } = {}
	for _, duration in DURATION_FIELDS_LARGEST_FIRST do
		local definition = assert(MetricUnitDefinitions.getUnit(duration.unitId), duration.unitId)
		table.insert(units, { field = duration.field, factor = definition.factor })
	end
	local frozen = table.freeze(units)
	durationUnitsLargestFirst = frozen
	return frozen
end

function MetricUnitFormatUtils._unitTranslationKey(unitId: string, display: UnitDisplay, pluralCategory: string): string
	return "units." .. unitId .. "." .. display .. "." .. pluralCategory
end

function MetricUnitFormatUtils._perUnit(unit: string): UnitDefinition
	local per = MetricUnitDefinitions.getUnit(unit)
	assert(
		per and TIME_LOCALIZATION_FIELD_BY_UNIT_ID[per.id] and per.id ~= "millisecond",
		string.format("Bad per unit %q, expected a second, minute, hour, day, week, month or year", unit)
	)
	return per
end

function MetricUnitFormatUtils._perPhrase(
	per: UnitDefinition,
	numeratorText: string,
	options: MetricUnitFormatOptions
): string
	local display: UnitDisplay = options.unitDisplay or "short"

	local override = if options.perStrings then options.perStrings[per.id] else nil
	local template = if override then (override :: any)[display] else nil
	if template == nil and options.translator then
		local translated = MetricUnitFormatUtils._tryTranslate(
			options,
			{ "per." .. per.id .. "." .. display },
			{ n = numeratorText }
		)
		if translated then
			return translated
		end
	end
	if template == nil then
		local names = (MetricUnitFormatUtils._getUnitLocale(options).per :: any)[per.id]
		assert(names, string.format("No per phrase for %q", per.id))
		template = names[display]
	end

	return (string.gsub(template, "%%s", function()
		return numeratorText
	end))
end

function MetricUnitFormatUtils._formatRelative(
	amount: number,
	dimensions: MetricUnitDimensionUtils.Dimensions,
	options: MetricUnitFormatOptions,
	unit: (string | UnitDefinition)?,
	absolute: boolean?
): string
	if next(dimensions) == nil and unit == nil then
		return (MetricUnitFormatUtils._formatNumber(amount, options))
	end

	if unit then
		local definition = MetricUnitFormatUtils._getUnit(options, unit)
		if not definition then
			error(
				string.format("MetricUnitFormatUtils: no unit %q", if type(unit) == "string" then unit else unit.id),
				3
			)
		end
		if MetricUnitDimensionUtils.equal(definition.dimensions, dimensions) then
			if definition.per then
				return MetricUnitFormatUtils._formatRate(amount, dimensions, options, nil, definition.per)
			end
			return MetricUnitFormatUtils._unitPhrase(
				definition,
				MetricUnitFormatUtils._amountIn(amount, definition, absolute),
				options
			)
		elseif not MetricUnitFormatUtils._isPerTime(dimensions) then
			error(
				string.format(
					"MetricUnitFormatUtils: %s is %s, not %s",
					definition.id,
					MetricUnitDimensionUtils.describe(definition.dimensions),
					MetricUnitDimensionUtils.describe(dimensions)
				),
				3
			)
		end
	end

	local isRateWrittenAsAsked = (unit ~= nil or options.perUnit ~= nil)
		and MetricUnitFormatUtils._isPerTime(dimensions)
	if isRateWrittenAsAsked then
		return MetricUnitFormatUtils._formatRate(amount, dimensions, options, unit, options.perUnit)
	end

	local units = MetricUnitDisplayUnitUtils.getDisplayUnits(dimensions, options._system, absolute)
	if units then
		local definition
		if options.autoUnit == false then
			definition = MetricUnitDisplayUnitUtils.getBaseUnit(
				MetricUnitDisplayUnitUtils.getDisplayUnits(dimensions, nil, absolute) or units
			)
		else
			definition = MetricUnitDisplayUnitUtils.pickDisplayUnit(amount, units)
		end
		return MetricUnitFormatUtils._unitPhrase(
			definition,
			MetricUnitFormatUtils._amountIn(amount, definition, absolute),
			options
		)
	end

	if MetricUnitFormatUtils._isPerTime(dimensions) then
		return MetricUnitFormatUtils._formatRate(amount, dimensions, options, unit, options.perUnit)
	end

	return MetricUnitFormatUtils._formatInBaseUnitSymbols(amount, dimensions, options)
end

function MetricUnitFormatUtils._amountIn(amount: number, definition: UnitDefinition, absolute: boolean?): number
	local fromZero = if absolute then amount - (definition.zero or 0) else amount
	return fromZero / definition.factor
end

function MetricUnitFormatUtils._isPerTime(dimensions: MetricUnitDimensionUtils.Dimensions): boolean
	if dimensions.time == -1 then
		return true
	end
	local numerator = MetricUnitDimensionUtils.combine(dimensions, MetricUnitKinds.TIME, 1)
	return MetricUnitDisplayUnitUtils.getDisplayUnits(numerator) ~= nil
end

function MetricUnitFormatUtils._formatRate(
	amount: number,
	dimensions: MetricUnitDimensionUtils.Dimensions,
	options: MetricUnitFormatOptions,
	numeratorUnit: (string | UnitDefinition)?,
	perUnit: string?
): string
	local per = if perUnit
		then MetricUnitFormatUtils._perUnit(perUnit)
		else MetricUnitDisplayUnitUtils.pickDisplayPerUnit(amount)

	local numerator = MetricUnitDimensionUtils.combine(dimensions, MetricUnitKinds.TIME, 1)
	local numeratorText = MetricUnitFormatUtils._formatRelative(amount * per.factor, numerator, options, numeratorUnit)
	return MetricUnitFormatUtils._perPhrase(per, numeratorText, options)
end

function MetricUnitFormatUtils._formatInBaseUnitSymbols(
	amount: number,
	dimensions: MetricUnitDimensionUtils.Dimensions,
	options: MetricUnitFormatOptions
): string
	local names: { string } = {}
	for name in dimensions do
		table.insert(names, name)
	end
	table.sort(names)

	local over: { string } = {}
	local under: { string } = {}
	for _, name in names do
		local exponent = dimensions[name]
		local symbol = MetricUnitDisplayUnitUtils.getBaseSymbol(name)
		local power = math.abs(exponent)
		local part = if power == 1 then symbol else symbol .. (SUPERSCRIPTS[power] or "^" .. tostring(power))
		table.insert(if exponent > 0 then over else under, part)
	end

	local text = MetricUnitFormatUtils._formatNumber(amount, options)
	if #over > 0 then
		text ..= MetricUnitFormatUtils.NO_BREAK_SPACE .. table.concat(over, "·")
	end
	for _, part in under do
		text ..= "/" .. part
	end
	return text
end

function MetricUnitFormatUtils._formatDuration(seconds: number, options: MetricUnitFormatOptions): string
	if options.unit then
		local definition = MetricUnitFormatUtils._getUnit(options, options.unit)
		assert(
			definition and definition.duration,
			string.format("MetricUnitFormatUtils: %s is not a time unit", tostring(options.unit))
		)
		return MetricUnitFormatUtils._durationUnitPhrase(definition, seconds / definition.factor, options)
	end

	if options.durationTemplate or options.durationStyle == "clock" then
		return MetricUnitFormatUtils._formatClock(seconds, options)
	end

	local magnitude = math.abs(seconds)
	if magnitude == 0 then
		return MetricUnitFormatUtils._durationPhrase("seconds", 0, options)
	elseif magnitude < 1e-3 then
		local microsecond = assert(MetricUnitDefinitions.getUnit("microsecond"), "No microsecond")
		return MetricUnitFormatUtils._durationUnitPhrase(microsecond, seconds / microsecond.factor, options)
	end

	local parts = MetricUnitFormatUtils._breakDuration(magnitude, options.maxParts or DEFAULT_DURATION_PARTS)
	local pieces: { string } = {}
	for _, part in parts do
		local count = if #pieces == 0 and seconds < 0 then -part.count else part.count
		table.insert(pieces, MetricUnitFormatUtils._durationPhrase(part.field, count, options))
	end
	return table.concat(pieces, options.separator or ", ")
end

function MetricUnitFormatUtils._durationUnitPhrase(
	definition: UnitDefinition,
	amount: number,
	options: MetricUnitFormatOptions
): string
	local timeLocalizationField = TIME_LOCALIZATION_FIELD_BY_UNIT_ID[definition.id]
	if timeLocalizationField then
		return MetricUnitFormatUtils._durationPhrase(timeLocalizationField, amount, options)
	elseif definition.id == "microsecond" then
		local hasLongNames = MetricUnitFallbackStrings.hasLocale(options.locale)
		local display: UnitDisplay = if hasLongNames then "long" else "short"
		return MetricUnitFormatUtils._unitPhrase(definition, amount, options, display)
	end
	error(string.format("MetricUnitFormatUtils: no duration word for %q", definition.id))
end

function MetricUnitFormatUtils._formatClock(seconds: number, options: MetricUnitFormatOptions): string
	local template = options.durationTemplate or "h:*mm:ss"
	local tokensOutsideBracketedLiterals = string.gsub(template, "%b[]", "")
	if string.find(tokensOutsideBracketedLiterals, YEAR_OR_MONTH_CLOCK_TOKENS) then
		error(
			string.format(
				'MetricUnitFormatUtils: durationTemplate %q counts years or months, which TimeDurationUtils sizes differently from MetricUnit; use durationStyle = "words"',
				template
			),
			4
		)
	end
	return TimeDurationUtils.format(seconds, template)
end

type DurationPart = { field: string, count: number }

function MetricUnitFormatUtils._breakDuration(seconds: number, maxParts: number): { DurationPart }
	assert(maxParts >= 1, "Bad maxParts")

	local roundedParts = MetricUnitFormatUtils._breakDurationRoundingSmallestPart(seconds, maxParts)
	local roundedTotal = MetricUnitFormatUtils._totalSeconds(roundedParts)
	if roundedTotal == 0 then
		return roundedParts
	end

	local partsWithRoundingCarried = MetricUnitFormatUtils._breakDurationRoundingSmallestPart(roundedTotal, maxParts)
	return partsWithRoundingCarried
end

function MetricUnitFormatUtils._totalSeconds(parts: { DurationPart }): number
	local total = 0
	for _, part in parts do
		total += part.count * MetricUnitFormatUtils._durationScale(part.field)
	end
	return total
end

function MetricUnitFormatUtils._breakDurationRoundingSmallestPart(seconds: number, maxParts: number): { DurationPart }
	local smallest = MetricUnitFormatUtils._smallestKeptUnitIndex(seconds, maxParts)
	local counts = MetricUnitFormatUtils._countWholeUnitsRoundingTheSmallest(seconds, smallest)
	local parts: { DurationPart } = {}
	for index = 1, smallest do
		if counts[index] ~= 0 then
			table.insert(
				parts,
				{ field = MetricUnitFormatUtils._durationUnitsLargestFirst()[index].field, count = counts[index] }
			)
		end
	end
	if #parts == 0 then
		table.insert(parts, { field = MetricUnitFormatUtils._durationUnitsLargestFirst()[smallest].field, count = 0 })
	end
	return parts
end

function MetricUnitFormatUtils._smallestKeptUnitIndex(seconds: number, maxParts: number): number
	local exactCounts = MetricUnitFormatUtils._countWholeUnitsRoundingTheSmallest(
		seconds,
		#MetricUnitFormatUtils._durationUnitsLargestFirst()
	)

	local smallest = #MetricUnitFormatUtils._durationUnitsLargestFirst()
	local nonZeroUnitsKept = 0
	for index, count in exactCounts do
		if count ~= 0 then
			nonZeroUnitsKept += 1
			smallest = index
			if nonZeroUnitsKept >= maxParts then
				break
			end
		end
	end
	return smallest
end

function MetricUnitFormatUtils._countWholeUnitsRoundingTheSmallest(seconds: number, smallest: number): { number }
	local counts: { number } = {}
	local remaining = seconds
	for index, unit in MetricUnitFormatUtils._durationUnitsLargestFirst() do
		local count = 0
		if index < smallest then
			count = math.floor(remaining / unit.factor + WHOLE_UNIT_TOLERANCE)
		elseif index == smallest then
			count = math.floor(remaining / unit.factor + 0.5)
		end
		remaining -= count * unit.factor
		counts[index] = count
	end
	return counts
end

function MetricUnitFormatUtils._durationScale(field: string): number
	for _, unit in MetricUnitFormatUtils._durationUnitsLargestFirst() do
		if unit.field == field then
			return unit.factor
		end
	end
	error(string.format("No duration unit %q", field))
end

function MetricUnitFormatUtils._joinNumberToUnitWithNoBreakSpace(text: string, numberText: string): string
	local start, finish = string.find(text, numberText .. " ", 1, true)
	if start and finish then
		return string.sub(text, 1, finish - 1) .. MetricUnitFormatUtils.NO_BREAK_SPACE .. string.sub(text, finish + 1)
	end
	return text
end

function MetricUnitFormatUtils._replaceFirst(text: string, plain: string, replacement: string): string
	local start, finish = string.find(text, plain, 1, true)
	if start and finish then
		return string.sub(text, 1, start - 1) .. replacement .. string.sub(text, finish + 1)
	end
	return text
end

function MetricUnitFormatUtils._durationPhrase(field: string, amount: number, options: MetricUnitFormatOptions): string
	local numberText, rounded, fraction = MetricUnitFormatUtils._formatNumber(amount, options)

	local overrides = options.durationStrings
	local phrase = if overrides then overrides[field] else nil
	if phrase == nil then
		phrase = (TimeLocalizationUtils.getDurationStringsForLocale(options.locale) :: any)[field]
	end
	assert(phrase, string.format("No duration phrase for %q", field))

	if type(phrase) == "function" then
		local textWithTostringNumber = phrase(rounded)
		local text = MetricUnitFormatUtils._replaceFirst(textWithTostringNumber, tostring(rounded), numberText)
		return MetricUnitFormatUtils._joinNumberToUnitWithNoBreakSpace(text, numberText)
	end

	local template = MetricUnitFormatUtils._pickPluralTemplate(phrase, options.locale, rounded, fraction)
	return MetricUnitFormatUtils._joinNumberToUnitWithNoBreakSpace((string.gsub(template, "%%d", function()
		return numberText
	end)), numberText)
end

return table.freeze(MetricUnitFormatUtils)
