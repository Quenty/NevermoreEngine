--!strict
--[=[
	Every unit [MetricUnit] can be made in, read in, parsed from and written in. This list is where a unit is
	declared: its id, dimensions, size in SI base units, symbol, measurement system, English names and the other
	text it may be typed as. [MetricUnit], [MetricUnitFormatUtils], [MetricUnitParseUtils] and
	[MetricUnitFallbackStrings] all read it. Symbols are the SI ones (or the customary ones for US and imperial
	units), which do not change with the locale.

	To add a unit:

	1. Add a row to the `define` call for its dimension and system below. See [UnitRow] for the fields. Give an SI
	   unit `prefixes` rather than adding its prefixed forms: `kilo`, `nano` and the rest are made from it.
	2. Add its id to the `UnitId` union, with any prefixed forms games commonly name. luau-lsp rejects a row whose
	   id is missing from it; other prefixed ids work at runtime.
	3. Add it to a system's display units in [MetricUnitSystems] if it should be picked by size.
	4. If it is written by name, add `units.<id>.long.<category>` and `units.<id>.short.<category>` for all six
	   plural categories to every `Localization/MetricUnitTranslator/<locale>.json.txt`: English from this row, the
	   other languages from CLDR's unit patterns. Prefixed forms need no entry; they are written from the
	   `prefixes` section and the unit's own entry.
	5. Only for a unit games construct constantly, add a named constructor on [MetricUnit].

	The specs catch a named unit without English names or translation keys, and a unit that does not round-trip
	through [MetricUnit.new] and [MetricUnit.In].

	@class MetricUnitDefinitions
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")
local MetricUnitKinds = require("MetricUnitKinds")
local Time = require("Time")

local MetricUnitDefinitions = {}

--[=[
	A unit's id: the singular, camelCase name of the unit. Every id has an entry in [MetricUnitDefinitions]; reading,
	formatting and [MetricUnit.new] all take it, so a typo is a type error.

	@type UnitId "microsecond" | "millisecond" | "second" | "minute" | "hour" | "day" | "week" | "month" | "quarter" | "year" | "perSecond" | "perMinute" | "perHour" | "perDay" | "perWeek" | "perMonth" | "perYear" | "hertz" | "percent" | "permille" | "millimeter" | "centimeter" | "meter" | "kilometer" | "inch" | "foot" | "yard" | "mile" | "stud" | "squareMillimeter" | "squareCentimeter" | "squareMeter" | "hectare" | "squareKilometer" | "squareFoot" | "acre" | "milliliter" | "liter" | "cubicMeter" | "usFluidOunce" | "usGallon" | "imperialGallon" | "bit" | "kilobit" | "megabit" | "gigabit" | "byte" | "kilobyte" | "megabyte" | "gigabyte" | "kibibyte" | "mebibyte" | "gibibyte" | "bitPerSecond" | "kilobitPerSecond" | "megabitPerSecond" | "gigabitPerSecond" | "bytePerSecond" | "kilobytePerSecond" | "milligram" | "gram" | "kilogram" | "tonne" | "ounce" | "pound" | "stone" | "robloxMassUnit" | "meterPerSecond" | "kilometerPerHour" | "milePerHour" | "knot" | "studPerSecond" | "meterPerSecondSquared" | "studPerSecondSquared" | "newton" | "kilonewton" | "meganewton" | "poundForce" | "joule" | "kilojoule" | "megajoule" | "kilowattHour" | "kilocalorie" | "watt" | "kilowatt" | "megawatt" | "pascal" | "kilopascal" | "megapascal" | "bar" | "poundForcePerSquareInch" | "kilogramPerCubicMeter" | "gramPerCubicCentimeter" | "kelvin" | "celsius" | "fahrenheit" | "radian" | "degree" | "revolution" | "radianPerSecond" | "degreePerSecond" | "revolutionPerMinute" | "radianPerSecondSquared" | "microampere" | "milliampere" | "ampere" | "coulomb" | "millivolt" | "volt" | "kilovolt" | "ohm" | "kilohm" | "megohm" | "siemens" | "picofarad" | "nanofarad" | "microfarad" | "farad" | "microhenry" | "millihenry" | "henry" | "weber" | "millitesla" | "tesla" | "nanometer" | "micrometer" | "centiliter" | "deciliter" | "terabyte" | "petabyte" | "microgram" | "milliwatt" | "gigawatt" | "kilohertz" | "megahertz" | "gigahertz" | "becquerel" | "mole" | "millimole" | "micromole" | "kilomole" | "gramPerMole" | "molePerLiter" | "millimolePerLiter" | "katal" | "candela" | "steradian" | "lumen" | "lux" | "kilolux" | "gray" | "milligray" | "sievert" | "millisievert" | "microsievert" | "nauticalMile" | "literPer100Kilometers" | "squareInch" | "squareYard" | "squareMile" | "cubicInch" | "cubicFoot" | "cubicYard" | "usTeaspoon" | "usTablespoon" | "usCup" | "usPint" | "usQuart" | "imperialFluidOunce" | "imperialPint" | "imperialQuart" | "shortTon" | "footPerSecond" | "footPerSecondSquared" | "newtonMeter" | "britishThermalUnit" | "poundFoot" | "metricHorsepower" | "horsepower" | "inchOfMercury" | "poundPerCubicFoot" | "kilometerPerLiter" | "milePerUsGallon" | "milePerImperialGallon" | "rankine"
	@within MetricUnitDefinitions
]=]
export type UnitId =
	"microsecond"
	| "millisecond"
	| "second"
	| "minute"
	| "hour"
	| "day"
	| "week"
	| "month"
	| "quarter"
	| "year"
	| "perSecond"
	| "perMinute"
	| "perHour"
	| "perDay"
	| "perWeek"
	| "perMonth"
	| "perYear"
	| "hertz"
	| "percent"
	| "permille"
	| "millimeter"
	| "centimeter"
	| "meter"
	| "kilometer"
	| "inch"
	| "foot"
	| "yard"
	| "mile"
	| "stud"
	| "squareMillimeter"
	| "squareCentimeter"
	| "squareMeter"
	| "hectare"
	| "squareKilometer"
	| "squareFoot"
	| "acre"
	| "milliliter"
	| "liter"
	| "cubicMeter"
	| "usFluidOunce"
	| "usGallon"
	| "imperialGallon"
	| "bit"
	| "kilobit"
	| "megabit"
	| "gigabit"
	| "byte"
	| "kilobyte"
	| "megabyte"
	| "gigabyte"
	| "kibibyte"
	| "mebibyte"
	| "gibibyte"
	| "bitPerSecond"
	| "kilobitPerSecond"
	| "megabitPerSecond"
	| "gigabitPerSecond"
	| "bytePerSecond"
	| "kilobytePerSecond"
	| "milligram"
	| "gram"
	| "kilogram"
	| "tonne"
	| "ounce"
	| "pound"
	| "stone"
	| "robloxMassUnit"
	| "meterPerSecond"
	| "kilometerPerHour"
	| "milePerHour"
	| "knot"
	| "studPerSecond"
	| "meterPerSecondSquared"
	| "studPerSecondSquared"
	| "newton"
	| "kilonewton"
	| "meganewton"
	| "poundForce"
	| "joule"
	| "kilojoule"
	| "megajoule"
	| "kilowattHour"
	| "kilocalorie"
	| "watt"
	| "kilowatt"
	| "megawatt"
	| "pascal"
	| "kilopascal"
	| "megapascal"
	| "bar"
	| "poundForcePerSquareInch"
	| "kilogramPerCubicMeter"
	| "gramPerCubicCentimeter"
	| "kelvin"
	| "celsius"
	| "fahrenheit"
	| "radian"
	| "degree"
	| "revolution"
	| "radianPerSecond"
	| "degreePerSecond"
	| "revolutionPerMinute"
	| "radianPerSecondSquared"
	| "microampere"
	| "milliampere"
	| "ampere"
	| "coulomb"
	| "millivolt"
	| "volt"
	| "kilovolt"
	| "ohm"
	| "kilohm"
	| "megohm"
	| "siemens"
	| "picofarad"
	| "nanofarad"
	| "microfarad"
	| "farad"
	| "microhenry"
	| "millihenry"
	| "henry"
	| "weber"
	| "millitesla"
	| "tesla"
	| "nanometer"
	| "micrometer"
	| "centiliter"
	| "deciliter"
	| "terabyte"
	| "petabyte"
	| "microgram"
	| "milliwatt"
	| "gigawatt"
	| "kilohertz"
	| "megahertz"
	| "gigahertz"
	| "becquerel"
	| "mole"
	| "millimole"
	| "micromole"
	| "kilomole"
	| "gramPerMole"
	| "molePerLiter"
	| "millimolePerLiter"
	| "katal"
	| "candela"
	| "steradian"
	| "lumen"
	| "lux"
	| "kilolux"
	| "gray"
	| "milligray"
	| "sievert"
	| "millisievert"
	| "microsievert"
	| "nauticalMile"
	| "literPer100Kilometers"
	| "squareInch"
	| "squareYard"
	| "squareMile"
	| "cubicInch"
	| "cubicFoot"
	| "cubicYard"
	| "usTeaspoon"
	| "usTablespoon"
	| "usCup"
	| "usPint"
	| "usQuart"
	| "imperialFluidOunce"
	| "imperialPint"
	| "imperialQuart"
	| "shortTon"
	| "footPerSecond"
	| "footPerSecondSquared"
	| "newtonMeter"
	| "britishThermalUnit"
	| "poundFoot"
	| "metricHorsepower"
	| "horsepower"
	| "inchOfMercury"
	| "poundPerCubicFoot"
	| "kilometerPerLiter"
	| "milePerUsGallon"
	| "milePerImperialGallon"
	| "rankine"

--[=[
	A unit id, any of `@quenty/time`'s names for a time unit, such as `"hours"` or `"h"`, or a unit itself, such as
	`MINI:GetUnit("stud")` from a [MetricUnitSystem] of the game's own scale.

	@type UnitLike UnitId | Time.TimeUnit | UnitDefinition
	@within MetricUnitDefinitions
]=]
export type UnitLike = UnitId | Time.TimeUnit | UnitDefinition

--[=[
	The name of the [MetricUnitSystem] that declares a unit: `"metric"`, `"usCustomary"`, `"imperial"`,
	`"usCustomaryAndImperial"` for the units the United States and Britain share (the inch, mile, pound, mph, BTU,
	horsepower), `"roblox"`, or a game's own system. Time units and bare rates belong to none, since every system
	shares them.

	@type UnitFamily string
	@within MetricUnitDefinitions
]=]
export type UnitFamily = string

--[=[
	A singular and plural form of a unit's English name or phrase.

	@interface UnitForms
	.one string
	.other string
	@within MetricUnitDefinitions
]=]
export type UnitForms = { one: string, other: string }

--[=[
	One unit.

	- `factor` is its size in SI base units: seconds, metres, kilograms, bytes, kelvin, radians, amperes, moles or
	  candelas, or their product for a derived unit, so a newton is 1 (kg·m/s²) and a kilowatt-hour 3,600,000 (J).
	- `names` is its American English name, for units written by name. Commonwealth spelling (metre, litre, tonne)
	  is derived.
	- `shortTemplates` replaces the default short phrase, the symbol after a space, where that reads wrongly
	  (`45%`, `45°`, `1 stud`). `%s` is the number.
	- `duration` marks the time units, which durations are written in.
	- `prefix` is set on a unit made from a prefix and another unit, such as `kilometer`.

	The other fields are as in [UnitRow].

	@interface UnitDefinition
	.id UnitId
	.dimensions Dimensions
	.factor number
	.symbol string
	.system UnitFamily?
	.names UnitForms?
	.shortTemplates UnitForms?
	.aliases { string }?
	.zero number?
	.per UnitId?
	.duration boolean?
	.prefix UnitPrefixOf?
	@within MetricUnitDefinitions
]=]
export type UnitDefinition = {
	id: UnitId,
	dimensions: MetricUnitDimensionUtils.Dimensions,
	factor: number,
	symbol: string,
	system: UnitFamily?,
	names: UnitForms?,
	shortTemplates: UnitForms?,
	aliases: { string }?,
	zero: number?,
	per: UnitId?,
	duration: boolean?,
	prefix: UnitPrefixOf?,
}

--[=[
	For a unit made by prefixing another, the prefix's name and the unit it prefixes: `kilometer` is `kilo` and
	`meter`. A translator writes it from those two when it has no entry for the unit itself.

	@interface UnitPrefixOf
	.name string
	.base UnitId
	@within MetricUnitDefinitions
]=]
export type UnitPrefixOf = { name: string, base: UnitId }

--[=[
	One row of the list below, for a unit of the kind (`"length"`, `"speed"`) and system its `define` call gives.

	- `factor` is its size in SI base units.
	- `name` is its American English singular, for units written by name; `plural` defaults to `name` plus "s".
	  Time units are written with `@quenty/time`'s words and bare rates with per phrases, so they have none.
	- `short` replaces the symbol-after-a-space short phrase, as one template or a singular and plural.
	- `aliases` is other text it may be typed as when parsed, such as `"kph"`.
	- `zero` is where the unit's scale starts, in base units. A unit with one is a scale whose readings are points:
	  [MetricUnit.new] makes absolute values in it. Only the temperature scales have one.
	- `per` is the time unit a bare rate such as `perHour` counts per. Hertz is a rate too, but is written by name.
	- `prefixes` makes a unit for each prefix of a [PrefixSet]: `meter` with `"si"` makes `kilometer`, `nanometer`
	  and the rest, with names, symbols and aliases from the unit's. A unit declared outright keeps its own row.
	- `elidesPrefixVowel` drops a prefix's final vowel before the unit, as SI writes `kilohm` and `megohm`.

	@interface UnitRow
	.id UnitId
	.factor number
	.symbol string
	.name string?
	.plural string?
	.short (string | UnitForms)?
	.aliases { string }?
	.zero number?
	.per UnitId?
	.prefixes PrefixSet?
	.elidesPrefixVowel boolean?
	@within MetricUnitDefinitions
]=]
export type UnitRow = {
	id: UnitId,
	factor: number,
	symbol: string,
	name: string?,
	plural: string?,
	short: (string | UnitForms)?,
	aliases: { string }?,
	zero: number?,
	per: UnitId?,
	prefixes: PrefixSet?,
	elidesPrefixVowel: boolean?,
}

--[=[
	A metric or binary prefix: `kilo` is `k` and 1000.

	@interface Prefix
	.name string
	.symbol string
	.factor number
	@within MetricUnitDefinitions
]=]
export type Prefix = { name: string, symbol: string, factor: number }

--[=[
	Which prefixes a unit takes: `"si"` all twenty-four SI prefixes, `"siMultiples"` only those of 10 and above (no
	millibytes), and `"siMultiplesAndBinary"` those and the binary ones (`KiB`, `MiB`).

	@type PrefixSet "si" | "siMultiples" | "siMultiplesAndBinary"
	@within MetricUnitDefinitions
]=]
export type PrefixSet = "si" | "siMultiples" | "siMultiplesAndBinary"

--[=[
	Metres in a Roblox stud, as Roblox documents it against the default avatar: 28 cm.

	@prop ROBLOX_METERS_PER_STUD number
	@within MetricUnitDefinitions
]=]
MetricUnitDefinitions.ROBLOX_METERS_PER_STUD = 0.28

-- stylua: ignore
local SI_PREFIXES: { Prefix } = {
	{ name = "quecto", symbol = "q", factor = 1e-30 }, { name = "ronto", symbol = "r", factor = 1e-27 },
	{ name = "yocto", symbol = "y", factor = 1e-24 }, { name = "zepto", symbol = "z", factor = 1e-21 },
	{ name = "atto", symbol = "a", factor = 1e-18 }, { name = "femto", symbol = "f", factor = 1e-15 },
	{ name = "pico", symbol = "p", factor = 1e-12 }, { name = "nano", symbol = "n", factor = 1e-9 },
	{ name = "micro", symbol = "µ", factor = 1e-6 }, { name = "milli", symbol = "m", factor = 1e-3 },
	{ name = "centi", symbol = "c", factor = 1e-2 }, { name = "deci", symbol = "d", factor = 1e-1 },
	{ name = "deca", symbol = "da", factor = 1e1 }, { name = "hecto", symbol = "h", factor = 1e2 },
	{ name = "kilo", symbol = "k", factor = 1e3 }, { name = "mega", symbol = "M", factor = 1e6 },
	{ name = "giga", symbol = "G", factor = 1e9 }, { name = "tera", symbol = "T", factor = 1e12 },
	{ name = "peta", symbol = "P", factor = 1e15 }, { name = "exa", symbol = "E", factor = 1e18 },
	{ name = "zetta", symbol = "Z", factor = 1e21 }, { name = "yotta", symbol = "Y", factor = 1e24 },
	{ name = "ronna", symbol = "R", factor = 1e27 }, { name = "quetta", symbol = "Q", factor = 1e30 },
}

-- stylua: ignore
local BINARY_PREFIXES: { Prefix } = {
	{ name = "kibi", symbol = "Ki", factor = 1024 }, { name = "mebi", symbol = "Mi", factor = 1024 ^ 2 },
	{ name = "gibi", symbol = "Gi", factor = 1024 ^ 3 }, { name = "tebi", symbol = "Ti", factor = 1024 ^ 4 },
	{ name = "pebi", symbol = "Pi", factor = 1024 ^ 5 }, { name = "exbi", symbol = "Ei", factor = 1024 ^ 6 },
	{ name = "zebi", symbol = "Zi", factor = 1024 ^ 7 }, { name = "yobi", symbol = "Yi", factor = 1024 ^ 8 },
}

local SI_MULTIPLES: { Prefix } = {}
for _, prefix in SI_PREFIXES do
	if prefix.factor > 1 then
		table.insert(SI_MULTIPLES, prefix)
	end
end

local SI_MULTIPLES_AND_BINARY: { Prefix } = table.clone(SI_MULTIPLES)
table.move(BINARY_PREFIXES, 1, #BINARY_PREFIXES, #SI_MULTIPLES_AND_BINARY + 1, SI_MULTIPLES_AND_BINARY)

local PREFIX_SETS: { [PrefixSet]: { Prefix } } = {
	si = SI_PREFIXES,
	siMultiples = SI_MULTIPLES,
	siMultiplesAndBinary = SI_MULTIPLES_AND_BINARY,
}

local ALL_PREFIXES: { Prefix } = table.clone(SI_PREFIXES)
table.move(BINARY_PREFIXES, 1, #BINARY_PREFIXES, #ALL_PREFIXES + 1, ALL_PREFIXES)

local QUENTY_TIME_UNIT_ALIASES: { [string]: string } = table.freeze({
	milliseconds = "millisecond",
	ms = "millisecond",
	seconds = "second",
	s = "second",
	minutes = "minute",
	m = "minute",
	hours = "hour",
	h = "hour",
	days = "day",
	d = "day",
	D = "day",
	date = "day",
	weeks = "week",
	w = "week",
	months = "month",
	M = "month",
	quarters = "quarter",
	Q = "quarter",
	years = "year",
	y = "year",
}) :: any

local function toDefinition(kind: MetricUnitKinds.KindName, system: UnitFamily?, row: UnitRow): UnitDefinition
	local dimensions = MetricUnitKinds.fromName(kind)
	local name = row.name
	local short = row.short
	return {
		id = row.id,
		dimensions = dimensions,
		factor = row.factor,
		symbol = row.symbol,
		system = system,
		names = if name then { one = name, other = row.plural or name .. "s" } else nil,
		shortTemplates = if type(short) == "string" then { one = short, other = short } else short,
		aliases = row.aliases,
		zero = row.zero,
		per = row.per,
		duration = if MetricUnitDimensionUtils.equal(dimensions, MetricUnitKinds.TIME) then true else nil,
	}
end

local function withPrefix(prefix: Prefix, word: string, elidesPrefixVowel: boolean?): string
	local lastLetter = string.sub(prefix.name, -1)
	if elidesPrefixVowel and (lastLetter == "a" or lastLetter == "o") then
		return string.sub(prefix.name, 1, -2) .. word
	end
	return prefix.name .. word
end

local function prefixedAliases(prefix: Prefix, base: UnitDefinition): { string }?
	local aliases: { string } = {}
	if prefix.name == "micro" then
		table.insert(aliases, "u" .. base.symbol)
	end
	local baseAliases: { string } = base.aliases or {}
	for _, alias in baseAliases do
		local isWord = string.match(alias, "^%a%a%a+$") ~= nil
		table.insert(aliases, if isWord then prefix.name .. alias else prefix.symbol .. alias)
	end
	return if #aliases > 0 then aliases else nil
end

local function toPrefixedDefinition(prefix: Prefix, base: UnitDefinition, elidesPrefixVowel: boolean?): UnitDefinition
	local names = base.names
	return {
		id = withPrefix(prefix, base.id, elidesPrefixVowel) :: any,
		dimensions = base.dimensions,
		factor = prefix.factor * base.factor,
		symbol = prefix.symbol .. base.symbol,
		system = base.system,
		names = if names
			then {
				one = withPrefix(prefix, names.one, elidesPrefixVowel),
				other = withPrefix(prefix, names.other, elidesPrefixVowel),
			}
			else nil,
		aliases = prefixedAliases(prefix, base),
		prefix = { name = prefix.name, base = base.id },
	}
end

type Define = (kind: MetricUnitKinds.KindName, system: UnitFamily?, rows: { UnitRow }) -> ()

local function robloxRows(metersPerStud: number): { { kind: MetricUnitKinds.KindName, row: UnitRow } }
	local waterKilogramsPerCubicMeter = 1_000
	-- stylua: ignore
	return {
		{ kind = "length", row = { id = "stud", factor = metersPerStud, symbol = "stud", name = "stud", short = { one = "%s stud", other = "%s studs" } } },
		{ kind = "mass", row = { id = "robloxMassUnit", factor = metersPerStud ^ 3 * waterKilogramsPerCubicMeter, symbol = "RMU", name = "Roblox mass unit" } },
		{ kind = "speed", row = { id = "studPerSecond", factor = metersPerStud, symbol = "stud/s", name = "stud per second", plural = "studs per second", short = { one = "%s stud/s", other = "%s studs/s" }, aliases = { "studs/s" } } },
		{ kind = "acceleration", row = { id = "studPerSecondSquared", factor = metersPerStud, symbol = "stud/s²", name = "stud per second squared", plural = "studs per second squared", short = { one = "%s stud/s²", other = "%s studs/s²" }, aliases = { "studs/s²", "studs/s2" } } },
	}
end

local DAY = 86_400
-- Julian year, an elapsed-time average for long-range math; calendar years are @quenty/time's Time.add
local JULIAN_YEAR = 365.25 * DAY
local AVERAGE_MONTH = JULIAN_YEAR / 12
local INCH = 0.0254
local MILE = 1_609.344
local FOOT = 12 * INCH
local US_GALLON = 3.785411784e-3
local IMPERIAL_GALLON = 4.54609e-3
local POUND = 0.45359237
local STANDARD_GRAVITY = 9.80665
local DEGREE = math.pi / 180
local REVOLUTION = 2 * math.pi
local CELSIUS_ZERO = 273.15
local BIT = 1 / 8
local POUND_FORCE = POUND * STANDARD_GRAVITY

-- stylua: ignore
local function declareWellKnownUnits(define: Define)
	define("time", nil, {
		{ id = "microsecond", factor = 1e-6, symbol = "µs", name = "microsecond", aliases = { "us" } },
		{ id = "millisecond", factor = 1e-3, symbol = "ms", aliases = { "msec", "msecs" } },
		{ id = "second", factor = 1, symbol = "s", aliases = { "sec", "secs" } },
		{ id = "minute", factor = 60, symbol = "min", aliases = { "mins" } },
		{ id = "hour", factor = 3_600, symbol = "h", aliases = { "hr", "hrs" } },
		{ id = "day", factor = DAY, symbol = "d" },
		{ id = "week", factor = 7 * DAY, symbol = "wk", aliases = { "wks" } },
		{ id = "month", factor = AVERAGE_MONTH, symbol = "mo", aliases = { "mos" } },
		{ id = "quarter", factor = JULIAN_YEAR / 4, symbol = "qtr" },
		{ id = "year", factor = JULIAN_YEAR, symbol = "yr", aliases = { "yrs" } },
	})

	define("rate", nil, {
		{ id = "perSecond", factor = 1, symbol = "/s", per = "second" },
		{ id = "perMinute", factor = 1 / 60, symbol = "/min", per = "minute" },
		{ id = "perHour", factor = 1 / 3_600, symbol = "/h", per = "hour" },
		{ id = "perDay", factor = 1 / DAY, symbol = "/d", per = "day" },
		{ id = "perWeek", factor = 1 / (7 * DAY), symbol = "/wk", per = "week" },
		{ id = "perMonth", factor = 12 / JULIAN_YEAR, symbol = "/mo", per = "month" },
		{ id = "perYear", factor = 1 / JULIAN_YEAR, symbol = "/yr", per = "year" },
	})
	define("rate", "metric", {
		{ id = "hertz", factor = 1, symbol = "Hz", name = "hertz", plural = "hertz", prefixes = "si" },
		{ id = "becquerel", factor = 1, symbol = "Bq", name = "becquerel", prefixes = "si" },
	})

	-- Proportions
	define("none", "metric", {
		{ id = "percent", factor = 1e-2, symbol = "%", name = "percent", plural = "percent", short = "%s%", aliases = { "pct" } },
		{ id = "permille", factor = 1e-3, symbol = "‰", name = "per mille", plural = "per mille", short = "%s‰" },
	})

	define("length", "metric", {
		{ id = "meter", factor = 1, symbol = "m", name = "meter", prefixes = "si" },
	})
	define("length", "usCustomaryAndImperial", {
		{ id = "inch", factor = INCH, symbol = "in", name = "inch", plural = "inches" },
		{ id = "foot", factor = FOOT, symbol = "ft", name = "foot", plural = "feet" },
		{ id = "yard", factor = 3 * FOOT, symbol = "yd", name = "yard" },
		{ id = "mile", factor = MILE, symbol = "mi", name = "mile" },
		{ id = "nauticalMile", factor = 1_852, symbol = "nmi", name = "nautical mile" },
	})

	define("area", "metric", {
		{ id = "squareMillimeter", factor = 1e-6, symbol = "mm²", name = "square millimeter", aliases = { "mm2" } },
		{ id = "squareCentimeter", factor = 1e-4, symbol = "cm²", name = "square centimeter", aliases = { "cm2" } },
		{ id = "squareMeter", factor = 1, symbol = "m²", name = "square meter", aliases = { "m2", "sq m" } },
		{ id = "hectare", factor = 1e4, symbol = "ha", name = "hectare" },
		{ id = "squareKilometer", factor = 1e6, symbol = "km²", name = "square kilometer", aliases = { "km2", "sq km" } },
	})
	define("area", "metric", {
		{ id = "literPer100Kilometers", factor = 1e-3 / 1e5, symbol = "L/100 km", name = "liter per 100 kilometers", plural = "liters per 100 kilometers", aliases = { "L/100km", "l/100km" } },
	})
	define("area", "usCustomaryAndImperial", {
		{ id = "squareInch", factor = INCH ^ 2, symbol = "in²", name = "square inch", plural = "square inches", aliases = { "in2", "sq in" } },
		{ id = "squareFoot", factor = FOOT ^ 2, symbol = "ft²", name = "square foot", plural = "square feet", aliases = { "ft2", "sq ft" } },
		{ id = "squareYard", factor = (3 * FOOT) ^ 2, symbol = "yd²", name = "square yard", aliases = { "yd2", "sq yd" } },
		{ id = "acre", factor = 4_046.8564224, symbol = "ac", name = "acre" },
		{ id = "squareMile", factor = MILE ^ 2, symbol = "mi²", name = "square mile", aliases = { "mi2", "sq mi" } },
	})

	define("volume", "metric", {
		{ id = "liter", factor = 1e-3, symbol = "L", name = "liter", aliases = { "l" }, prefixes = "si" },
		{ id = "cubicMeter", factor = 1, symbol = "m³", name = "cubic meter", aliases = { "m3" } },
	})
	define("volume", "usCustomaryAndImperial", {
		{ id = "cubicInch", factor = INCH ^ 3, symbol = "in³", name = "cubic inch", plural = "cubic inches", aliases = { "in3", "cu in" } },
		{ id = "cubicFoot", factor = FOOT ^ 3, symbol = "ft³", name = "cubic foot", plural = "cubic feet", aliases = { "ft3", "cu ft" } },
		{ id = "cubicYard", factor = (3 * FOOT) ^ 3, symbol = "yd³", name = "cubic yard", aliases = { "yd3", "cu yd" } },
	})
	define("volume", "usCustomary", {
		{ id = "usTeaspoon", factor = US_GALLON / 768, symbol = "tsp", name = "teaspoon" },
		{ id = "usTablespoon", factor = US_GALLON / 256, symbol = "tbsp", name = "tablespoon" },
		{ id = "usFluidOunce", factor = US_GALLON / 128, symbol = "US fl oz", name = "US fluid ounce", aliases = { "fl oz" } },
		{ id = "usCup", factor = US_GALLON / 16, symbol = "cup", name = "cup", short = { one = "%s cup", other = "%s cups" } },
		{ id = "usPint", factor = US_GALLON / 8, symbol = "US pt", name = "US pint", aliases = { "pt" } },
		{ id = "usQuart", factor = US_GALLON / 4, symbol = "US qt", name = "US quart", aliases = { "qt" } },
		{ id = "usGallon", factor = US_GALLON, symbol = "US gal", name = "US gallon", aliases = { "gal" } },
	})
	define("volume", "imperial", {
		{ id = "imperialFluidOunce", factor = IMPERIAL_GALLON / 160, symbol = "imp fl oz", name = "imperial fluid ounce" },
		{ id = "imperialPint", factor = IMPERIAL_GALLON / 8, symbol = "imp pt", name = "imperial pint" },
		{ id = "imperialQuart", factor = IMPERIAL_GALLON / 4, symbol = "imp qt", name = "imperial quart" },
		{ id = "imperialGallon", factor = IMPERIAL_GALLON, symbol = "imp gal", name = "imperial gallon" },
	})

	define("memory", "metric", {
		{ id = "bit", factor = BIT, symbol = "bit", name = "bit", prefixes = "siMultiples" },
		{ id = "byte", factor = 1, symbol = "B", name = "byte", prefixes = "siMultiplesAndBinary" },
		{ id = "kilobyte", factor = 1e3, symbol = "kB", name = "kilobyte", aliases = { "KB" } },
	})

	define("dataRate", "metric", {
		{ id = "bitPerSecond", factor = BIT, symbol = "bit/s", name = "bit per second", plural = "bits per second", aliases = { "bps" } },
		{ id = "kilobitPerSecond", factor = 1e3 * BIT, symbol = "kbit/s", name = "kilobit per second", plural = "kilobits per second", aliases = { "kbps" } },
		{ id = "megabitPerSecond", factor = 1e6 * BIT, symbol = "Mbit/s", name = "megabit per second", plural = "megabits per second", aliases = { "Mbps" } },
		{ id = "gigabitPerSecond", factor = 1e9 * BIT, symbol = "Gbit/s", name = "gigabit per second", plural = "gigabits per second", aliases = { "Gbps" } },
		{ id = "bytePerSecond", factor = 1, symbol = "B/s", name = "byte per second", plural = "bytes per second" },
		{ id = "kilobytePerSecond", factor = 1e3, symbol = "kB/s", name = "kilobyte per second", plural = "kilobytes per second", aliases = { "KB/s" } },
	})

	define("mass", "metric", {
		{ id = "gram", factor = 1e-3, symbol = "g", name = "gram", prefixes = "si" },
		{ id = "tonne", factor = 1e3, symbol = "t", name = "metric ton" },
	})
	define("mass", "usCustomaryAndImperial", {
		{ id = "ounce", factor = POUND / 16, symbol = "oz", name = "ounce" },
		{ id = "pound", factor = POUND, symbol = "lb", name = "pound", aliases = { "lbs" } },
	})
	define("mass", "usCustomary", {
		{ id = "shortTon", factor = 2_000 * POUND, symbol = "tn", name = "short ton", aliases = { "ton", "tons" } },
	})
	define("mass", "imperial", {
		{ id = "stone", factor = 14 * POUND, symbol = "st", name = "stone", plural = "stone" },
	})

	define("speed", "metric", {
		{ id = "meterPerSecond", factor = 1, symbol = "m/s", name = "meter per second", plural = "meters per second" },
		{ id = "kilometerPerHour", factor = 1e3 / 3_600, symbol = "km/h", name = "kilometer per hour", plural = "kilometers per hour", aliases = { "kph", "kmh", "km/hr" } },
	})
	define("speed", "usCustomaryAndImperial", {
		{ id = "milePerHour", factor = MILE / 3_600, symbol = "mph", name = "mile per hour", plural = "miles per hour", aliases = { "mi/h" } },
		{ id = "footPerSecond", factor = FOOT, symbol = "ft/s", name = "foot per second", plural = "feet per second", aliases = { "fps" } },
		{ id = "knot", factor = 1_852 / 3_600, symbol = "kn", name = "knot", aliases = { "kt" } },
	})

	define("acceleration", "metric", {
		{ id = "meterPerSecondSquared", factor = 1, symbol = "m/s²", name = "meter per second squared", plural = "meters per second squared", aliases = { "m/s2" } },
	})
	define("acceleration", "usCustomaryAndImperial", {
		{ id = "footPerSecondSquared", factor = FOOT, symbol = "ft/s²", name = "foot per second squared", plural = "feet per second squared", aliases = { "ft/s2" } },
	})

	define("force", "metric", {
		{ id = "newton", factor = 1, symbol = "N", name = "newton", prefixes = "si" },
	})
	define("force", "usCustomaryAndImperial", {
		{ id = "poundForce", factor = POUND_FORCE, symbol = "lbf", name = "pound-force", plural = "pounds-force" },
	})

	define("energy", "metric", {
		{ id = "joule", factor = 1, symbol = "J", name = "joule", prefixes = "si" },
		{ id = "kilowattHour", factor = 3.6e6, symbol = "kWh", name = "kilowatt-hour" },
		{ id = "kilocalorie", factor = 4_184, symbol = "kcal", name = "kilocalorie" },
		{ id = "newtonMeter", factor = 1, symbol = "N·m", name = "newton-meter", aliases = { "Nm", "N m" } },
	})
	define("energy", "usCustomaryAndImperial", {
		{ id = "britishThermalUnit", factor = 1_055.05585262, symbol = "Btu", name = "British thermal unit", aliases = { "BTU" } },
		{ id = "poundFoot", factor = POUND_FORCE * FOOT, symbol = "lbf·ft", name = "pound-foot", plural = "pound-feet", aliases = { "lb-ft", "lb·ft", "ft-lb", "ft·lbf" } },
	})

	define("power", "metric", {
		{ id = "watt", factor = 1, symbol = "W", name = "watt", prefixes = "si" },
		{ id = "metricHorsepower", factor = 735.49875, symbol = "PS", name = "metric horsepower", plural = "metric horsepower", aliases = { "CV", "ch" } },
	})
	define("power", "usCustomaryAndImperial", {
		{ id = "horsepower", factor = 550 * POUND_FORCE * FOOT, symbol = "hp", name = "horsepower", plural = "horsepower", aliases = { "bhp" } },
	})

	define("pressure", "metric", {
		{ id = "pascal", factor = 1, symbol = "Pa", name = "pascal", prefixes = "si" },
		{ id = "bar", factor = 1e5, symbol = "bar", name = "bar" },
	})
	define("pressure", "usCustomaryAndImperial", {
		{ id = "poundForcePerSquareInch", factor = POUND_FORCE / INCH ^ 2, symbol = "psi", name = "pound-force per square inch", plural = "pounds-force per square inch" },
		{ id = "inchOfMercury", factor = 3_386.389, symbol = "inHg", name = "inch of mercury", plural = "inches of mercury" },
	})

	define("density", "metric", {
		{ id = "kilogramPerCubicMeter", factor = 1, symbol = "kg/m³", name = "kilogram per cubic meter", plural = "kilograms per cubic meter", aliases = { "kg/m3" } },
		{ id = "gramPerCubicCentimeter", factor = 1e3, symbol = "g/cm³", name = "gram per cubic centimeter", plural = "grams per cubic centimeter", aliases = { "g/cm3" } },
	})
	define("density", "usCustomaryAndImperial", {
		{ id = "poundPerCubicFoot", factor = POUND / FOOT ^ 3, symbol = "lb/ft³", name = "pound per cubic foot", plural = "pounds per cubic foot", aliases = { "lb/ft3" } },
	})

	define("fuelEconomy", "metric", {
		{ id = "kilometerPerLiter", factor = 1e3 / 1e-3, symbol = "km/L", name = "kilometer per liter", plural = "kilometers per liter", aliases = { "kmpl" } },
	})
	define("fuelEconomy", "usCustomary", {
		{ id = "milePerUsGallon", factor = MILE / US_GALLON, symbol = "mpg (US)", name = "mile per US gallon", plural = "miles per US gallon", aliases = { "mpg" } },
	})
	define("fuelEconomy", "imperial", {
		{ id = "milePerImperialGallon", factor = MILE / IMPERIAL_GALLON, symbol = "mpg (UK)", name = "mile per imperial gallon", plural = "miles per imperial gallon", aliases = { "mpg UK", "mpg imp" } },
	})

	define("temperature", "metric", {
		{ id = "kelvin", factor = 1, symbol = "K", name = "kelvin", zero = 0 },
		{ id = "celsius", factor = 1, symbol = "°C", name = "degree Celsius", plural = "degrees Celsius", aliases = { "C", "degC", "°c" }, zero = CELSIUS_ZERO },
	})
	define("temperature", "usCustomaryAndImperial", {
		{ id = "fahrenheit", factor = 5 / 9, symbol = "°F", name = "degree Fahrenheit", plural = "degrees Fahrenheit", aliases = { "F", "degF", "°f" }, zero = 459.67 * 5 / 9 },
		{ id = "rankine", factor = 5 / 9, symbol = "°R", name = "degree Rankine", plural = "degrees Rankine", zero = 0 },
	})

	define("angle", "metric", {
		{ id = "radian", factor = 1, symbol = "rad", name = "radian", aliases = { "rads" } },
		{ id = "degree", factor = DEGREE, symbol = "°", name = "degree", short = "%s°", aliases = { "deg", "degs" } },
		{ id = "revolution", factor = REVOLUTION, symbol = "rev", name = "revolution", aliases = { "turn", "turns", "revs" } },
	})

	define("angularVelocity", "metric", {
		{ id = "radianPerSecond", factor = 1, symbol = "rad/s", name = "radian per second", plural = "radians per second" },
		{ id = "degreePerSecond", factor = DEGREE, symbol = "°/s", name = "degree per second", plural = "degrees per second", aliases = { "deg/s" } },
		{ id = "revolutionPerMinute", factor = REVOLUTION / 60, symbol = "rpm", name = "revolution per minute", plural = "revolutions per minute", aliases = { "RPM", "rev/min" } },
	})

	define("angularAcceleration", "metric", {
		{ id = "radianPerSecondSquared", factor = 1, symbol = "rad/s²", name = "radian per second squared", plural = "radians per second squared", aliases = { "rad/s2" } },
	})

	define("current", "metric", {
		{ id = "ampere", factor = 1, symbol = "A", name = "ampere", aliases = { "amp", "amps" }, prefixes = "si" },
	})

	define("charge", "metric", {
		{ id = "coulomb", factor = 1, symbol = "C", name = "coulomb", prefixes = "si" },
	})

	define("voltage", "metric", {
		{ id = "volt", factor = 1, symbol = "V", name = "volt", prefixes = "si" },
	})

	define("resistance", "metric", {
		{ id = "ohm", factor = 1, symbol = "Ω", name = "ohm", prefixes = "si", elidesPrefixVowel = true },
	})

	define("conductance", "metric", {
		{ id = "siemens", factor = 1, symbol = "S", name = "siemens", plural = "siemens", prefixes = "si" },
	})

	define("capacitance", "metric", {
		{ id = "farad", factor = 1, symbol = "F", name = "farad", prefixes = "si" },
	})

	define("inductance", "metric", {
		{ id = "henry", factor = 1, symbol = "H", name = "henry", plural = "henries", prefixes = "si" },
	})

	define("magneticFlux", "metric", {
		{ id = "weber", factor = 1, symbol = "Wb", name = "weber", prefixes = "si" },
	})

	define("amount", "metric", {
		{ id = "mole", factor = 1, symbol = "mol", name = "mole", prefixes = "si" },
	})
	define("molarMass", "metric", {
		{ id = "gramPerMole", factor = 1e-3, symbol = "g/mol", name = "gram per mole", plural = "grams per mole" },
	})
	define("molarConcentration", "metric", {
		{ id = "molePerLiter", factor = 1e3, symbol = "mol/L", name = "mole per liter", plural = "moles per liter" },
		{ id = "millimolePerLiter", factor = 1, symbol = "mmol/L", name = "millimole per liter", plural = "millimoles per liter" },
	})
	define("catalyticActivity", "metric", {
		{ id = "katal", factor = 1, symbol = "kat", name = "katal", prefixes = "si" },
	})

	define("luminousIntensity", "metric", {
		{ id = "candela", factor = 1, symbol = "cd", name = "candela", prefixes = "si" },
	})
	define("solidAngle", "metric", {
		{ id = "steradian", factor = 1, symbol = "sr", name = "steradian" },
	})
	define("luminousFlux", "metric", {
		{ id = "lumen", factor = 1, symbol = "lm", name = "lumen", prefixes = "si" },
	})
	define("illuminance", "metric", {
		{ id = "lux", factor = 1, symbol = "lx", name = "lux", plural = "lux", prefixes = "si" },
	})

	define("absorbedDose", "metric", {
		{ id = "gray", factor = 1, symbol = "Gy", name = "gray", prefixes = "si" },
		{ id = "sievert", factor = 1, symbol = "Sv", name = "sievert", prefixes = "si" },
	})

	for _, robloxRow in robloxRows(MetricUnitDefinitions.ROBLOX_METERS_PER_STUD) do
		define(robloxRow.kind, "roblox", { robloxRow.row })
	end

	define("magneticFluxDensity", "metric", {
		{ id = "tesla", factor = 1, symbol = "T", name = "tesla", prefixes = "si" },
	})
end

type Prefixing = { prefixes: { Prefix }, elidesPrefixVowel: boolean? }

type Registry = {
	declared: { UnitDefinition },
	byId: { [string]: UnitDefinition },
	prefixingByBaseId: { [string]: Prefixing },
	prefixableInOrder: { UnitDefinition },
	everyUnit: { UnitDefinition }?,
}

local registry: Registry? = nil

local function getRegistry(): Registry
	local found = registry
	if found then
		return found
	end

	local declared: { UnitDefinition } = {}
	local byId: { [string]: UnitDefinition } = {}
	local prefixingByBaseId: { [string]: Prefixing } = {}
	local prefixableInOrder: { UnitDefinition } = {}
	declareWellKnownUnits(function(kind: MetricUnitKinds.KindName, system: UnitFamily?, rows: { UnitRow })
		for _, row in rows do
			local unit = table.freeze(toDefinition(kind, system, row))
			assert(byId[unit.id] == nil, string.format("Unit %q is declared twice", unit.id))
			table.insert(declared, unit)
			byId[unit.id] = unit
			local prefixSet = row.prefixes
			if prefixSet then
				prefixingByBaseId[unit.id] =
					{ prefixes = PREFIX_SETS[prefixSet :: PrefixSet], elidesPrefixVowel = row.elidesPrefixVowel }
				table.insert(prefixableInOrder, unit)
			end
		end
	end)

	local built: Registry = {
		declared = table.freeze(declared),
		byId = byId,
		prefixingByBaseId = prefixingByBaseId,
		prefixableInOrder = prefixableInOrder,
		everyUnit = nil,
	}
	registry = built
	return built
end

local function findPrefixedUnitById(id: string): UnitDefinition?
	local byId = getRegistry().byId
	for _, prefix in ALL_PREFIXES do
		for _, prefixText in { prefix.name, string.sub(prefix.name, 1, -2) } do
			local base = if string.sub(id, 1, #prefixText) == prefixText
				then byId[string.sub(id, #prefixText + 1)]
				else nil
			local unit = if base then MetricUnitDefinitions.getPrefixedUnit(prefix, base) else nil
			if unit and unit.id == id then
				return unit
			end
		end
	end
	return nil
end

--[=[
	The unit named `unit`, or nil. Takes any [UnitLike], so `"hours"` and `"h"` find `"hour"`, and a unit is
	returned as it is.

	@param unit UnitLike
	@return UnitDefinition?
]=]
function MetricUnitDefinitions.getUnit(unit: string | UnitDefinition): UnitDefinition?
	if type(unit) == "table" then
		return if MetricUnitDefinitions.isUnitDefinition(unit) then unit :: UnitDefinition else nil
	end
	local byId = getRegistry().byId
	return byId[unit] or byId[QUENTY_TIME_UNIT_ALIASES[unit] or ""] or findPrefixedUnitById(unit)
end

--[=[
	The unit `prefix` makes of `base`, such as `kilometer` for `kilo` and `meter`, or nil when `base` does not take
	that prefix.

	@param prefix Prefix
	@param base UnitDefinition
	@return UnitDefinition?
]=]
function MetricUnitDefinitions.getPrefixedUnit(prefix: Prefix, base: UnitDefinition): UnitDefinition?
	local found = getRegistry()
	local prefixing = found.prefixingByBaseId[base.id]
	if not (prefixing and table.find(prefixing.prefixes, prefix)) then
		return nil
	end
	local id = withPrefix(prefix, base.id, prefixing.elidesPrefixVowel)
	local existing = found.byId[id]
	if existing then
		return existing
	end
	local unit = table.freeze(toPrefixedDefinition(prefix, base, prefixing.elidesPrefixVowel))
	found.byId[id] = unit
	return unit
end

--[=[
	The units declared outright, without their prefixed forms, in the order declared. Cheaper than
	[MetricUnitDefinitions.getUnits]; [MetricUnitDefinitions.getPrefixedUnit] finds the rest.

	@return { UnitDefinition }
]=]
function MetricUnitDefinitions.getDeclaredUnits(): { UnitDefinition }
	return getRegistry().declared
end

--[=[
	Every unit, in the order declared, then every prefixed form. Building the prefixed forms costs a few
	milliseconds the first time, so look units up with [MetricUnitDefinitions.getUnit] where you can.

	@return { UnitDefinition }
]=]
function MetricUnitDefinitions.getUnits(): { UnitDefinition }
	local found = getRegistry()
	local everyUnit = found.everyUnit
	if everyUnit then
		return everyUnit
	end
	local units = table.clone(found.declared)
	for _, base in found.prefixableInOrder do
		for _, prefix in found.prefixingByBaseId[base.id].prefixes do
			local unit = MetricUnitDefinitions.getPrefixedUnit(prefix, base)
			local isDeclaredOutright = unit ~= nil and unit.prefix == nil
			if unit and not isDeclaredOutright then
				table.insert(units, unit)
			end
		end
	end
	local frozen = table.freeze(units)
	found.everyUnit = frozen
	return frozen
end

--[=[
	The ids of every unit of `dimensions`, in the order declared.

	@param dimensions Dimensions
	@return { UnitId }
]=]
function MetricUnitDefinitions.getUnitIds(dimensions: MetricUnitDimensionUtils.Dimensions): { UnitId }
	local found: { UnitId } = {}
	for _, unit in MetricUnitDefinitions.getUnits() do
		if MetricUnitDimensionUtils.equal(unit.dimensions, dimensions) then
			table.insert(found, unit.id)
		end
	end
	return found
end

--[=[
	Every prefix a unit can take: the twenty-four SI prefixes, smallest first, then the binary ones.

	@return { Prefix }
]=]
function MetricUnitDefinitions.getPrefixes(): { Prefix }
	return ALL_PREFIXES
end

--[=[
	`@quenty/time`'s other names for its time units, such as `"h"` for `"hour"`, mapped to unit ids.

	@return { [string]: UnitId }
]=]
function MetricUnitDefinitions.getTimeAliases(): { [string]: UnitId }
	return QUENTY_TIME_UNIT_ALIASES :: any
end

--[=[
	Whether `value` is a [UnitDefinition], such as one [MetricUnitSystem.GetUnit] returns.

	@param value any
	@return boolean
]=]
function MetricUnitDefinitions.isUnitDefinition(value: any): boolean
	return type(value) == "table"
		and type(value.id) == "string"
		and type(value.factor) == "number"
		and type(value.symbol) == "string"
		and MetricUnitDimensionUtils.isDimensions(value.dimensions)
end

--[=[
	Units for a [MetricUnitSystem] of a game's own, from rows of one kind as in [UnitRow], with their prefixed forms.
	They are not added to the well-known units; only a system holding them knows them.

	```lua
	local units = MetricUnitDefinitions.createUnits("length", "space", {
		{ id = "lightYear", factor = 9.4607e15, symbol = "ly", name = "light-year" },
	})
	```

	@param kind KindName
	@param system string -- the name of the system that declares them
	@param rows { UnitRow }
	@return { UnitDefinition }
]=]
function MetricUnitDefinitions.createUnits(
	kind: MetricUnitKinds.KindName,
	system: string,
	rows: { UnitRow }
): { UnitDefinition }
	local definitions: { UnitDefinition } = {}
	local prefixables: { { base: UnitDefinition, row: UnitRow } } = {}
	for _, row in rows do
		local definition = toDefinition(kind, system, row)
		table.insert(definitions, definition)
		if row.prefixes then
			table.insert(prefixables, { base = definition, row = row })
		end
	end
	local declaredIds: { [string]: true } = {}
	for _, definition in definitions do
		declaredIds[definition.id] = true
	end
	for _, prefixable in prefixables do
		for _, prefix in PREFIX_SETS[prefixable.row.prefixes :: PrefixSet] do
			local unit = toPrefixedDefinition(prefix, prefixable.base, prefixable.row.elidesPrefixVowel)
			if not declaredIds[unit.id] then
				table.insert(definitions, unit)
			end
		end
	end
	for index, definition in definitions do
		definitions[index] = table.freeze(definition)
	end
	return table.freeze(definitions)
end

--[=[
	The Roblox units at a stud of `metersPerStud`: `stud`, `studPerSecond`, `studPerSecondSquared` and
	`robloxMassUnit`, a cubic stud of water, so it scales with the cube of the stud.

	@param system string -- the name of the system that declares them
	@param metersPerStud number
	@return { UnitDefinition }
]=]
function MetricUnitDefinitions.createRobloxUnits(system: string, metersPerStud: number): { UnitDefinition }
	assert(type(metersPerStud) == "number" and metersPerStud > 0, "Bad metersPerStud")
	local definitions: { UnitDefinition } = {}
	for _, robloxRow in robloxRows(metersPerStud) do
		for _, definition in MetricUnitDefinitions.createUnits(robloxRow.kind, system, { robloxRow.row }) do
			table.insert(definitions, definition)
		end
	end
	return table.freeze(definitions)
end

return table.freeze(MetricUnitDefinitions)
