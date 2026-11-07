--!strict
--[=[
	Writes measurements for people, in the style of JavaScript's `Intl.NumberFormat` with `style: "unit"`: a
	localized number, then the unit's symbol or name. The unit is picked to suit the value's size unless one is
	given, so 1,500 N is `1.5 kN`. Takes a [MetricUnit] or its plain [MetricUnitData].

	Numbers go through [NumberLocalizationUtils], so digit grouping and the decimal mark follow the locale. Unit
	names come from [MetricUnitLocalizationUtils], and duration words from [TimeLocalizationUtils].

	A duration is broken into years, months, days, hours, minutes and seconds with [MetricUnit]'s own averaged year
	and month (a Julian year, and a twelfth of it), not `@quenty/time`'s 365 and 30 days, so `MetricUnit.years(1)`
	reads `1 year` and `MetricUnit.months(1)` reads `1 month`. Only `@quenty/time`'s words are used. For a clock-style
	`h:mm:ss`, or calendar months, hand exact seconds to `TimeDurationUtils` or `Time` yourself.

	```lua
	MetricUnitFormatUtils.format(MetricUnit.meters(1500)) --> 1.5 km
	MetricUnitFormatUtils.format(MetricUnit.meters(1500), { unitDisplay = "long" }) --> 1.5 kilometers
	MetricUnitFormatUtils.format(MetricUnit.meters(1500), { system = "imperial" }) --> 4,921.26 ft
	MetricUnitFormatUtils.format({ amount = 1234.5, dimensions = { length = 1 } }, { unit = "meter", locale = "de-de" }) --> 1 234,5 m
	MetricUnitFormatUtils.format(MetricUnit.minutes(90)) --> 1 hour, 30 minutes
	MetricUnitFormatUtils.formatUnit("kilowattHour", 3) --> 3 kWh
	```

	@class MetricUnitFormatUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitCatalog = require("MetricUnitCatalog")
local MetricUnitDimensions = require("MetricUnitDimensions")
local MetricUnitLocalizationUtils = require("MetricUnitLocalizationUtils")
local MetricUnitScale = require("MetricUnitScale")
local NumberLocalizationUtils = require("NumberLocalizationUtils")
local Time = require("Time")
local TimeLocalizationUtils = require("TimeLocalizationUtils")

local MetricUnitFormatUtils = {}

local DEFAULT_LOCALE = "en-us"
local DEFAULT_MAXIMUM_FRACTION_DIGITS = 3
local DEFAULT_DURATION_PARTS = 2

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
	Options for [MetricUnitFormatUtils.format], modelled on `Intl.NumberFormat`.

	@interface MetricUnitFormatOptions
	.locale string? -- Picks the number format and unit names, defaults to `en-us`
	.unitDisplay UnitDisplay? -- `short` symbols (the default) or `long` names
	.unit UnitLike? -- Always write this unit; for a rate, the whole rate's (`kilometerPerHour`, `perHour`) or the numerator's (`kilometer`)
	.perUnit TimeUnit? -- Always write a rate per this time unit, such as `"hour"` or `"h"`
	.autoUnit boolean? -- Pick the unit that suits the size (the default), or always write the SI base unit
	.system UnitSystem? -- Which units to pick from: `metric` (the default) or `imperial` (miles, pounds, mph, °F where a dimension has them)
	.minimumFractionDigits number? -- Pad with zeros to at least this many decimals, defaults to 0
	.maximumFractionDigits number? -- Round to at most this many decimals, defaults to 3
	.maximumSignificantDigits number? -- Round to this many significant digits instead of fraction digits
	.useGrouping boolean? -- Group thousands for the locale, defaults to true
	.strings UnitStringOverrides? -- Overrides a unit's phrase, e.g. `{ kilometer = { short = "%s klicks" } }`
	.perStrings PerStringOverrides? -- Overrides a per phrase, e.g. `{ hour = { short = "%s an hour" } }`
	.durationStrings DurationStringOverrides? -- Overrides a duration word, as in `TimeDurationUtils`
	.maxParts number? -- How many non-zero units a duration is written in, largest first, defaults to 2
	.separator string? -- Between the parts of a duration, defaults to `, `
	@within MetricUnitFormatUtils
]=]
export type MetricUnitFormatOptions = {
	locale: string?,
	unitDisplay: UnitDisplay?,
	unit: MetricUnitCatalog.UnitLike?,
	perUnit: Time.TimeUnit?,
	autoUnit: boolean?,
	system: MetricUnitCatalog.UnitSystem?,
	minimumFractionDigits: number?,
	maximumFractionDigits: number?,
	maximumSignificantDigits: number?,
	useGrouping: boolean?,
	strings: MetricUnitLocalizationUtils.UnitStringOverrides?,
	perStrings: MetricUnitLocalizationUtils.PerStringOverrides?,
	durationStrings: TimeLocalizationUtils.DurationStringOverrides?,
	maxParts: number?,
	separator: string?,
}

type UnitDefinition = MetricUnitCatalog.UnitDefinition
type DurationUnit = { field: string, scale: number }

-- Duration parts, largest first, sized by MetricUnit's averaged year and month
local DURATION_UNITS: { DurationUnit } = {
	{ field = "years", scale = MetricUnitScale.YEAR },
	{ field = "months", scale = MetricUnitScale.MONTH },
	{ field = "days", scale = MetricUnitScale.DAY },
	{ field = "hours", scale = MetricUnitScale.HOUR },
	{ field = "minutes", scale = MetricUnitScale.MINUTE },
	{ field = "seconds", scale = MetricUnitScale.SECOND },
	{ field = "milliseconds", scale = MetricUnitScale.MILLISECOND },
}

-- TimeLocalizationUtils' duration field for each time unit it has a word for
local DURATION_FIELDS: { [string]: string } = {
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

	Studs and US customary units are only written when asked for, with `unit` or `system = "imperial"`.

	```lua
	local length = MetricUnit.meters(2500)
	MetricUnitFormatUtils.format(length) --> 2.5 km
	MetricUnitFormatUtils.format(length, { unit = "meter" }) --> 2,500 m
	MetricUnitFormatUtils.format(length, { unit = "stud" }) --> 8,925 studs
	MetricUnitFormatUtils.format(length, { unitDisplay = "long", locale = "en-gb" }) --> 2.5 kilometres
	MetricUnitFormatUtils.format(length, { maximumSignificantDigits = 1 }) --> 3 km
	```

	@param value MetricUnit | MetricUnitData
	@param options MetricUnitFormatOptions?
	@return string
]=]
function MetricUnitFormatUtils.format(
	-- Typed any at this one boundary: this module cannot name MetricUnit's type without requiring MetricUnit,
	-- which requires it, and the old solver does not match a metatable type against a structural record.
	-- _read checks the value at runtime.
	value: any,
	options: MetricUnitFormatOptions?
): string
	local amount, dimensions, absolute = MetricUnitFormatUtils._read(value)
	local resolved: MetricUnitFormatOptions = options or {}

	if MetricUnitDimensions.equal(dimensions, MetricUnitDimensions.TEMPERATURE) then
		return MetricUnitFormatUtils._formatTemperature(amount, absolute, resolved)
	elseif MetricUnitDimensions.equal(dimensions, MetricUnitDimensions.TIME) then
		return MetricUnitFormatUtils._formatDuration(amount, resolved)
	end
	return MetricUnitFormatUtils._formatRelative(amount, dimensions, resolved, resolved.unit)
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
	unit: MetricUnitCatalog.UnitLike,
	amount: number,
	options: MetricUnitFormatOptions?
): string
	assert(type(amount) == "number", "Bad amount")
	local definition = MetricUnitCatalog.getUnit(unit)
	assert(definition, string.format("No unit %q", tostring(unit)))

	local resolved: MetricUnitFormatOptions = options or {}
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

-- Reads a MetricUnit through its methods, or plain data through its fields
function MetricUnitFormatUtils._read(value: any): (number, MetricUnitDimensions.Dimensions, boolean)
	assert(type(value) == "table", "Bad value")
	if type(value.amount) == "number" then
		assert(MetricUnitDimensions.isDimensions(value.dimensions), "Bad dimensions")
		return value.amount, value.dimensions, value.absolute == true
	end
	assert(value.ClassName == "MetricUnit", "Bad value, expected a MetricUnit or MetricUnitData")
	return value:GetBaseAmount(), value:GetDimensions(), value:IsAbsolute()
end

-- The written number, the rounded value it shows, and whether it shows any decimals
function MetricUnitFormatUtils._formatNumber(value: number, options: MetricUnitFormatOptions): (string, number, boolean)
	if value ~= value or value == math.huge or value == -math.huge then
		return tostring(value), value, false
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
			rounded = MetricUnitFormatUtils._round(value, places)
			decimals = math.max(0, places)
		end
	else
		decimals = options.maximumFractionDigits or DEFAULT_MAXIMUM_FRACTION_DIGITS
		rounded = MetricUnitFormatUtils._round(value, decimals)
	end
	decimals = math.max(decimals, minimumFractionDigits)

	local digits = string.format("%." .. tostring(decimals) .. "f", math.abs(rounded))
	local integerPart, fractionPart = string.match(digits, "^(%d+)%.?(%d*)$")
	assert(integerPart and fractionPart, "Bad number")
	while #fractionPart > minimumFractionDigits and string.sub(fractionPart, -1) == "0" do
		fractionPart = string.sub(fractionPart, 1, -2)
	end

	local integerValue = tonumber(integerPart) :: number
	if options.useGrouping ~= false and integerValue < 1e15 then
		integerPart = NumberLocalizationUtils.localize(integerValue, locale)
	end

	local text = (if rounded < 0 then "-" else "") .. integerPart
	if #fractionPart > 0 then
		text ..= MetricUnitFormatUtils._getDecimalSeparator(locale) .. fractionPart
	end
	return text, rounded, #fractionPart > 0
end

-- Rounds half away from zero to `places` decimals; a negative `places` rounds to tens, hundreds and so on
function MetricUnitFormatUtils._round(value: number, places: number): number
	local factor = 10 ^ places
	local rounded = math.floor(math.abs(value) * factor + 0.5) / factor
	return if value < 0 and rounded ~= 0 then -rounded else rounded
end

-- NumberLocalizationUtils.localize groups digits but keeps "." as the decimal mark; abbreviate writes the locale's
-- mark, so a small number through it shows which one to use
function MetricUnitFormatUtils._getDecimalSeparator(locale: string): string
	local cached = decimalSeparators[locale]
	if cached then
		return cached
	end

	local sample = NumberLocalizationUtils.abbreviate(0.5, locale, nil, 1)
	local separator = string.match(sample, "^0(.-)5$") or "."
	decimalSeparators[locale] = separator
	return separator
end

function MetricUnitFormatUtils._getUnitLocale(options: MetricUnitFormatOptions): MetricUnitLocalizationUtils.UnitLocale
	-- Short phrases are symbols, the same in every language, so only long names warn about a missing locale
	if options.unitDisplay == "long" or MetricUnitLocalizationUtils.hasLocale(options.locale) then
		return MetricUnitLocalizationUtils.getLocale(options.locale)
	end
	return MetricUnitLocalizationUtils.getLocale(DEFAULT_LOCALE)
end

function MetricUnitFormatUtils._applyUnitPhrase(
	phrase: MetricUnitLocalizationUtils.UnitPhrase,
	rounded: number,
	numberText: string,
	hasFraction: boolean
): string
	if type(phrase) == "function" then
		return phrase(rounded, numberText)
	end
	local template = if math.abs(rounded) == 1 and not hasFraction then phrase.one else phrase.other
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
	local numberText, rounded, hasFraction = MetricUnitFormatUtils._formatNumber(amount, options)
	local resolvedDisplay: UnitDisplay = display or options.unitDisplay or "short"

	local override = if options.strings then options.strings[definition.id] else nil
	local phrase = if override then (override :: any)[resolvedDisplay] else nil
	if phrase == nil then
		local names = (MetricUnitFormatUtils._getUnitLocale(options).units :: any)[definition.id]
		assert(names, string.format("No phrase for unit %q", definition.id))
		phrase = names[resolvedDisplay]
	end

	return MetricUnitFormatUtils._applyUnitPhrase(phrase, rounded, numberText, hasFraction)
end

function MetricUnitFormatUtils._perUnit(unit: string): UnitDefinition
	local per = MetricUnitCatalog.getUnit(unit)
	assert(
		per and DURATION_FIELDS[per.id] and per.id ~= "millisecond",
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
	dimensions: MetricUnitDimensions.Dimensions,
	options: MetricUnitFormatOptions,
	unit: string?
): string
	if next(dimensions) == nil then
		return (MetricUnitFormatUtils._formatNumber(amount, options))
	end

	if unit then
		local definition = MetricUnitCatalog.getUnit(unit)
		assert(definition, string.format("No unit %q", unit))
		if MetricUnitDimensions.equal(definition.dimensions, dimensions) then
			if definition.per then
				return MetricUnitFormatUtils._formatRate(amount, dimensions, options, nil, definition.per)
			end
			return MetricUnitFormatUtils._unitPhrase(definition, amount / definition.scale, options)
		elseif dimensions.time ~= -1 then
			error(
				string.format(
					"MetricUnitFormatUtils: %s is %s, not %s",
					definition.id,
					MetricUnitDimensions.describe(definition.dimensions),
					MetricUnitDimensions.describe(dimensions)
				),
				3
			)
		end
	end

	local units = MetricUnitCatalog.getLadder(dimensions, options.system)
	if units then
		local definition
		if options.autoUnit == false then
			definition = MetricUnitCatalog.getBaseUnit(MetricUnitCatalog.getLadder(dimensions) or units)
		else
			definition = MetricUnitCatalog.pickFromLadder(amount, units)
		end
		return MetricUnitFormatUtils._unitPhrase(definition, amount / definition.scale, options)
	end

	if dimensions.time == -1 then
		return MetricUnitFormatUtils._formatRate(amount, dimensions, options, unit, options.perUnit)
	end

	return MetricUnitFormatUtils._formatBaseUnits(amount, dimensions, options)
end

function MetricUnitFormatUtils._formatRate(
	amount: number,
	dimensions: MetricUnitDimensions.Dimensions,
	options: MetricUnitFormatOptions,
	numeratorUnit: string?,
	perUnit: string?
): string
	local per = if perUnit then MetricUnitFormatUtils._perUnit(perUnit) else MetricUnitCatalog.pickPerUnit(amount)

	local numerator = MetricUnitDimensions.combine(dimensions, MetricUnitDimensions.TIME, 1)
	local numeratorText
	if MetricUnitDimensions.equal(numerator, MetricUnitDimensions.TEMPERATURE) then
		numeratorText = MetricUnitFormatUtils._formatTemperature(amount * per.scale, false, options)
	else
		numeratorText = MetricUnitFormatUtils._formatRelative(amount * per.scale, numerator, options, numeratorUnit)
	end
	return MetricUnitFormatUtils._perPhrase(per, numeratorText, options)
end

-- An unnamed compound, in SI base unit symbols such as `6 kg·m/s`
function MetricUnitFormatUtils._formatBaseUnits(
	amount: number,
	dimensions: MetricUnitDimensions.Dimensions,
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
		local symbol = MetricUnitCatalog.getBaseSymbol(name)
		local power = math.abs(exponent)
		local part = if power == 1 then symbol else symbol .. (SUPERSCRIPTS[power] or "^" .. tostring(power))
		table.insert(if exponent > 0 then over else under, part)
	end

	local text = MetricUnitFormatUtils._formatNumber(amount, options)
	if #over > 0 then
		text ..= " " .. table.concat(over, "·")
	end
	for _, part in under do
		text ..= "/" .. part
	end
	return text
end

function MetricUnitFormatUtils._formatTemperature(
	amount: number,
	absolute: boolean,
	options: MetricUnitFormatOptions
): string
	local definition: UnitDefinition
	if options.unit then
		local fixed = MetricUnitCatalog.getUnit(options.unit)
		assert(
			fixed and fixed.zero ~= nil,
			string.format("MetricUnitFormatUtils: %s is not a temperature unit", tostring(options.unit))
		)
		definition = fixed
	elseif options.system == "imperial" then
		definition = assert(MetricUnitCatalog.getUnit("fahrenheit"), "No fahrenheit")
	else
		definition = assert(MetricUnitCatalog.getUnit(if absolute then "celsius" else "kelvin"), "No unit")
	end

	local value = if absolute then (amount - (definition.zero or 0)) / definition.scale else amount / definition.scale
	return MetricUnitFormatUtils._unitPhrase(definition, value, options)
end

function MetricUnitFormatUtils._formatDuration(seconds: number, options: MetricUnitFormatOptions): string
	if options.unit then
		local definition = MetricUnitCatalog.getUnit(options.unit)
		assert(
			definition and definition.duration,
			string.format("MetricUnitFormatUtils: %s is not a time unit", tostring(options.unit))
		)
		return MetricUnitFormatUtils._durationUnitPhrase(definition, seconds / definition.scale, options)
	end

	local magnitude = math.abs(seconds)
	if magnitude == 0 then
		return MetricUnitFormatUtils._durationPhrase("seconds", 0, options)
	elseif magnitude < MetricUnitScale.MILLISECOND then
		local microsecond = assert(MetricUnitCatalog.getUnit("microsecond"), "No microsecond")
		return MetricUnitFormatUtils._durationUnitPhrase(microsecond, seconds / microsecond.scale, options)
	end

	local parts = MetricUnitFormatUtils._breakDuration(magnitude, options.maxParts or DEFAULT_DURATION_PARTS)
	local pieces: { string } = {}
	for _, part in parts do
		local count = if #pieces == 0 and seconds < 0 then -part.count else part.count
		table.insert(pieces, MetricUnitFormatUtils._durationPhrase(part.field, count, options))
	end
	return table.concat(pieces, options.separator or ", ")
end

-- One time unit as a duration word: @quenty/time's for the units it names, and for microseconds, which it does not,
-- this package's long name, or the µs symbol in a locale without names
function MetricUnitFormatUtils._durationUnitPhrase(
	definition: UnitDefinition,
	amount: number,
	options: MetricUnitFormatOptions
): string
	local field = DURATION_FIELDS[definition.id]
	if field then
		return MetricUnitFormatUtils._durationPhrase(field, amount, options)
	elseif definition.id == "microsecond" then
		local display: UnitDisplay = if MetricUnitLocalizationUtils.hasLocale(options.locale) then "long" else "short"
		return MetricUnitFormatUtils._unitPhrase(definition, amount, options, display)
	end
	error(string.format("MetricUnitFormatUtils: no duration word for %q", definition.id))
end

type DurationPart = { field: string, count: number }

--[[
	Breaks a positive duration into at most `maxParts` whole units, largest first, dropping zeros. Only the smallest
	is rounded, so a month stays a month although it is not a whole number of days. Rounding can fill a larger unit
	(1 day 23 hours 59.7 minutes to two parts rounds to 1 day 24 hours), so the rounded total is broken down again
	to carry it (2 days).
]]
function MetricUnitFormatUtils._breakDuration(seconds: number, maxParts: number): { DurationPart }
	assert(maxParts >= 1, "Bad maxParts")

	local parts = MetricUnitFormatUtils._breakDurationOnce(seconds, maxParts)
	local total = 0
	for _, part in parts do
		total += part.count * MetricUnitFormatUtils._durationScale(part.field)
	end
	if total == 0 then
		return parts
	end
	return MetricUnitFormatUtils._breakDurationOnce(total, maxParts)
end

-- Keeps the `maxParts` largest non-zero units, like TimeDurationUtils' `largest`, rounding the smallest kept one
function MetricUnitFormatUtils._breakDurationOnce(seconds: number, maxParts: number): { DurationPart }
	local exact = MetricUnitFormatUtils._countUnits(seconds, #DURATION_UNITS)

	local smallest = #DURATION_UNITS
	local kept = 0
	for index, count in exact do
		if count ~= 0 then
			kept += 1
			smallest = index
			if kept >= maxParts then
				break
			end
		end
	end

	local counts = MetricUnitFormatUtils._countUnits(seconds, smallest)
	local parts: { DurationPart } = {}
	for index = 1, smallest do
		if counts[index] ~= 0 then
			table.insert(parts, { field = DURATION_UNITS[index].field, count = counts[index] })
		end
	end
	if #parts == 0 then
		table.insert(parts, { field = DURATION_UNITS[smallest].field, count = 0 })
	end
	return parts
end

-- Whole counts of each unit down to `smallest`, which is rounded; the ones below it are zero
function MetricUnitFormatUtils._countUnits(seconds: number, smallest: number): { number }
	local counts: { number } = {}
	local remaining = seconds
	for index, unit in DURATION_UNITS do
		local count = 0
		if index < smallest then
			-- The tolerance keeps twelve averaged months, summed in floating point, a whole year
			count = math.floor(remaining / unit.scale + 1e-9)
		elseif index == smallest then
			count = math.floor(remaining / unit.scale + 0.5)
		end
		remaining -= count * unit.scale
		counts[index] = count
	end
	return counts
end

function MetricUnitFormatUtils._durationScale(field: string): number
	for _, unit in DURATION_UNITS do
		if unit.field == field then
			return unit.scale
		end
	end
	error(string.format("No duration unit %q", field))
end

-- One duration word from TimeLocalizationUtils, with the number written for the locale
function MetricUnitFormatUtils._durationPhrase(field: string, amount: number, options: MetricUnitFormatOptions): string
	local numberText, rounded, hasFraction = MetricUnitFormatUtils._formatNumber(amount, options)

	local overrides = options.durationStrings
	local phrase = if overrides then overrides[field] else nil
	if phrase == nil then
		phrase = (TimeLocalizationUtils.getDurationStringsForLocale(options.locale) :: any)[field]
	end
	assert(phrase, string.format("No duration phrase for %q", field))

	if type(phrase) == "function" then
		-- These write the amount with tostring; swap in the localized number
		local text = phrase(rounded)
		local plain = tostring(rounded)
		local start, finish = string.find(text, plain, 1, true)
		if start and finish then
			return string.sub(text, 1, start - 1) .. numberText .. string.sub(text, finish + 1)
		end
		return text
	end

	local template = if math.abs(rounded) == 1 and not hasFraction then phrase.one else phrase.other
	return (string.gsub(template, "%%d", function()
		return numberText
	end))
end

return table.freeze(MetricUnitFormatUtils)
