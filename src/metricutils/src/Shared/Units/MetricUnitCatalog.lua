--!strict
--[=[
	Every unit [MetricUnit] can be made in, read in and written in: its id, dimensions, size in SI base units and
	SI symbol, plus the ladders that pick a unit to suit a value's size. Symbols are the SI ones (or the customary
	ones for US and imperial units), which do not change with the locale. Names live in
	[MetricUnitLocalizationUtils].

	Every id here has exactly one constructor on [MetricUnit] and English names in [MetricUnitLocalizationUtils].
	Adding a unit means adding it in all three; the specs check that every unit written by name has names.

	@class MetricUnitCatalog
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitDimensions = require("MetricUnitDimensions")
local MetricUnitScale = require("MetricUnitScale")
local Time = require("Time")

local MetricUnitCatalog = {}

--[=[
	A unit's id: the singular, camelCase name of the unit. Each has a plural constructor on [MetricUnit]
	(`"kilometer"` and [MetricUnit.kilometers]), except the rates and the temperature scales, whose constructor has the
	id's name (`"perHour"` and [MetricUnit.perHour], `"celsius"` and [MetricUnit.celsius]).

	@type UnitId "microsecond" | "millisecond" | "second" | "minute" | "hour" | "day" | "week" | "month" | "quarter" | "year" | "perSecond" | "perMinute" | "perHour" | "perDay" | "perWeek" | "perMonth" | "perYear" | "hertz" | "millimeter" | "centimeter" | "meter" | "kilometer" | "inch" | "foot" | "yard" | "mile" | "stud" | "squareMillimeter" | "squareCentimeter" | "squareMeter" | "hectare" | "squareKilometer" | "squareFoot" | "acre" | "milliliter" | "liter" | "cubicMeter" | "usFluidOunce" | "usGallon" | "imperialGallon" | "byte" | "kilobyte" | "megabyte" | "gigabyte" | "kibibyte" | "mebibyte" | "gibibyte" | "bytePerSecond" | "kilobytePerSecond" | "milligram" | "gram" | "kilogram" | "tonne" | "ounce" | "pound" | "stone" | "meterPerSecond" | "kilometerPerHour" | "milePerHour" | "knot" | "studPerSecond" | "meterPerSecondSquared" | "newton" | "kilonewton" | "meganewton" | "poundForce" | "joule" | "kilojoule" | "megajoule" | "kilowattHour" | "kilocalorie" | "watt" | "kilowatt" | "megawatt" | "pascal" | "kilopascal" | "megapascal" | "bar" | "poundForcePerSquareInch" | "kilogramPerCubicMeter" | "gramPerCubicCentimeter" | "kelvin" | "celsius" | "fahrenheit"
	@within MetricUnitCatalog
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
	| "byte"
	| "kilobyte"
	| "megabyte"
	| "gigabyte"
	| "kibibyte"
	| "mebibyte"
	| "gibibyte"
	| "bytePerSecond"
	| "kilobytePerSecond"
	| "milligram"
	| "gram"
	| "kilogram"
	| "tonne"
	| "ounce"
	| "pound"
	| "stone"
	| "meterPerSecond"
	| "kilometerPerHour"
	| "milePerHour"
	| "knot"
	| "studPerSecond"
	| "meterPerSecondSquared"
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

--[=[
	A unit id, or any of `@quenty/time`'s names for a time unit, such as `"hours"` or `"h"`.

	@type UnitLike UnitId | Time.TimeUnit
	@within MetricUnitCatalog
]=]
export type UnitLike = UnitId | Time.TimeUnit

--[=[
	Which units the formatter picks from by size: SI units, or US customary ones (miles, pounds, °F) where a
	dimension has them.

	@type UnitSystem "metric" | "imperial"
	@within MetricUnitCatalog
]=]
export type UnitSystem = "metric" | "imperial"

--[=[
	One unit. `zero` is where an absolute scale's zero sits, in base units, for the temperature scales. `per` is the
	time unit a bare rate such as `perHour` counts per. `duration` marks the time units, which durations are
	written in.

	@interface UnitDefinition
	.id UnitId
	.dimensions Dimensions
	.scale number -- Its size in SI base units
	.symbol string
	.zero number?
	.per UnitId?
	.duration boolean
	@within MetricUnitCatalog
]=]
export type UnitDefinition = {
	id: UnitId,
	dimensions: MetricUnitDimensions.Dimensions,
	scale: number,
	symbol: string,
	zero: number?,
	per: UnitId?,
	duration: boolean,
}

local UNITS: { [string]: UnitDefinition } = {}
local ORDER: { UnitDefinition } = {}

local function define(
	id: string,
	dimensions: MetricUnitDimensions.Dimensions,
	scale: number,
	symbol: string,
	zero: number?,
	per: string?,
	duration: boolean
)
	local unit: UnitDefinition = table.freeze({
		id = id :: any,
		dimensions = dimensions,
		scale = scale,
		symbol = symbol,
		zero = zero,
		per = per :: any,
		duration = duration,
	})
	UNITS[id] = unit
	table.insert(ORDER, unit)
end

local D = MetricUnitDimensions
local S = MetricUnitScale

define("microsecond", D.TIME, S.MICROSECOND, "µs", nil, nil, true)
define("millisecond", D.TIME, S.MILLISECOND, "ms", nil, nil, true)
define("second", D.TIME, S.SECOND, "s", nil, nil, true)
define("minute", D.TIME, S.MINUTE, "min", nil, nil, true)
define("hour", D.TIME, S.HOUR, "h", nil, nil, true)
define("day", D.TIME, S.DAY, "d", nil, nil, true)
define("week", D.TIME, S.WEEK, "wk", nil, nil, true)
define("month", D.TIME, S.MONTH, "mo", nil, nil, true)
define("quarter", D.TIME, S.QUARTER, "qtr", nil, nil, true)
define("year", D.TIME, S.YEAR, "yr", nil, nil, true)
define("perSecond", D.RATE, 1 / S.SECOND, "/s", nil, "second", false)
define("perMinute", D.RATE, 1 / S.MINUTE, "/min", nil, "minute", false)
define("perHour", D.RATE, 1 / S.HOUR, "/h", nil, "hour", false)
define("perDay", D.RATE, 1 / S.DAY, "/d", nil, "day", false)
define("perWeek", D.RATE, 1 / S.WEEK, "/wk", nil, "week", false)
define("perMonth", D.RATE, 1 / S.MONTH, "/mo", nil, "month", false)
define("perYear", D.RATE, 1 / S.YEAR, "/yr", nil, "year", false)
define("hertz", D.RATE, 1 / S.SECOND, "Hz", nil, nil, false)
define("millimeter", D.LENGTH, S.MILLIMETER, "mm", nil, nil, false)
define("centimeter", D.LENGTH, S.CENTIMETER, "cm", nil, nil, false)
define("meter", D.LENGTH, S.METER, "m", nil, nil, false)
define("kilometer", D.LENGTH, S.KILOMETER, "km", nil, nil, false)
define("inch", D.LENGTH, S.INCH, "in", nil, nil, false)
define("foot", D.LENGTH, S.FOOT, "ft", nil, nil, false)
define("yard", D.LENGTH, S.YARD, "yd", nil, nil, false)
define("mile", D.LENGTH, S.MILE, "mi", nil, nil, false)
define("stud", D.LENGTH, S.STUD, "stud", nil, nil, false)
define("squareMillimeter", D.AREA, S.SQUARE_MILLIMETER, "mm²", nil, nil, false)
define("squareCentimeter", D.AREA, S.SQUARE_CENTIMETER, "cm²", nil, nil, false)
define("squareMeter", D.AREA, S.SQUARE_METER, "m²", nil, nil, false)
define("hectare", D.AREA, S.HECTARE, "ha", nil, nil, false)
define("squareKilometer", D.AREA, S.SQUARE_KILOMETER, "km²", nil, nil, false)
define("squareFoot", D.AREA, S.SQUARE_FOOT, "ft²", nil, nil, false)
define("acre", D.AREA, S.ACRE, "ac", nil, nil, false)
define("milliliter", D.VOLUME, S.MILLILITER, "mL", nil, nil, false)
define("liter", D.VOLUME, S.LITER, "L", nil, nil, false)
define("cubicMeter", D.VOLUME, S.CUBIC_METER, "m³", nil, nil, false)
define("usFluidOunce", D.VOLUME, S.US_FLUID_OUNCE, "US fl oz", nil, nil, false)
define("usGallon", D.VOLUME, S.US_GALLON, "US gal", nil, nil, false)
define("imperialGallon", D.VOLUME, S.IMPERIAL_GALLON, "imp gal", nil, nil, false)
define("byte", D.MEMORY, S.BYTE, "B", nil, nil, false)
define("kilobyte", D.MEMORY, S.KILOBYTE, "kB", nil, nil, false)
define("megabyte", D.MEMORY, S.MEGABYTE, "MB", nil, nil, false)
define("gigabyte", D.MEMORY, S.GIGABYTE, "GB", nil, nil, false)
define("kibibyte", D.MEMORY, S.KIBIBYTE, "KiB", nil, nil, false)
define("mebibyte", D.MEMORY, S.MEBIBYTE, "MiB", nil, nil, false)
define("gibibyte", D.MEMORY, S.GIBIBYTE, "GiB", nil, nil, false)
define("bytePerSecond", D.DATA_RATE, S.BYTE, "B/s", nil, nil, false)
define("kilobytePerSecond", D.DATA_RATE, S.KILOBYTE, "kB/s", nil, nil, false)
define("milligram", D.MASS, S.MILLIGRAM, "mg", nil, nil, false)
define("gram", D.MASS, S.GRAM, "g", nil, nil, false)
define("kilogram", D.MASS, S.KILOGRAM, "kg", nil, nil, false)
define("tonne", D.MASS, S.TONNE, "t", nil, nil, false)
define("ounce", D.MASS, S.OUNCE, "oz", nil, nil, false)
define("pound", D.MASS, S.POUND, "lb", nil, nil, false)
define("stone", D.MASS, S.STONE, "st", nil, nil, false)
define("meterPerSecond", D.SPEED, S.METER_PER_SECOND, "m/s", nil, nil, false)
define("kilometerPerHour", D.SPEED, S.KILOMETER_PER_HOUR, "km/h", nil, nil, false)
define("milePerHour", D.SPEED, S.MILE_PER_HOUR, "mph", nil, nil, false)
define("knot", D.SPEED, S.KNOT, "kn", nil, nil, false)
define("studPerSecond", D.SPEED, S.STUD_PER_SECOND, "stud/s", nil, nil, false)
define("meterPerSecondSquared", D.ACCELERATION, S.METER_PER_SECOND_SQUARED, "m/s²", nil, nil, false)
define("newton", D.FORCE, S.NEWTON, "N", nil, nil, false)
define("kilonewton", D.FORCE, S.KILONEWTON, "kN", nil, nil, false)
define("meganewton", D.FORCE, S.MEGANEWTON, "MN", nil, nil, false)
define("poundForce", D.FORCE, S.POUND_FORCE, "lbf", nil, nil, false)
define("joule", D.ENERGY, S.JOULE, "J", nil, nil, false)
define("kilojoule", D.ENERGY, S.KILOJOULE, "kJ", nil, nil, false)
define("megajoule", D.ENERGY, S.MEGAJOULE, "MJ", nil, nil, false)
define("kilowattHour", D.ENERGY, S.KILOWATT_HOUR, "kWh", nil, nil, false)
define("kilocalorie", D.ENERGY, S.KILOCALORIE, "kcal", nil, nil, false)
define("watt", D.POWER, S.WATT, "W", nil, nil, false)
define("kilowatt", D.POWER, S.KILOWATT, "kW", nil, nil, false)
define("megawatt", D.POWER, S.MEGAWATT, "MW", nil, nil, false)
define("pascal", D.PRESSURE, S.PASCAL, "Pa", nil, nil, false)
define("kilopascal", D.PRESSURE, S.KILOPASCAL, "kPa", nil, nil, false)
define("megapascal", D.PRESSURE, S.MEGAPASCAL, "MPa", nil, nil, false)
define("bar", D.PRESSURE, S.BAR, "bar", nil, nil, false)
define("poundForcePerSquareInch", D.PRESSURE, S.POUND_FORCE_PER_SQUARE_INCH, "psi", nil, nil, false)
define("kilogramPerCubicMeter", D.DENSITY, S.KILOGRAM_PER_CUBIC_METER, "kg/m³", nil, nil, false)
define("gramPerCubicCentimeter", D.DENSITY, S.GRAM_PER_CUBIC_CENTIMETER, "g/cm³", nil, nil, false)
define("kelvin", D.TEMPERATURE, S.KELVIN, "K", 0, nil, false)
define("celsius", D.TEMPERATURE, S.CELSIUS, "°C", S.CELSIUS_ZERO, nil, false)
define("fahrenheit", D.TEMPERATURE, S.FAHRENHEIT, "°F", S.FAHRENHEIT_ZERO, nil, false)

table.freeze(UNITS)
table.freeze(ORDER)

-- @quenty/time's other names for its time units
local TIME_ALIASES: { [string]: string } = table.freeze({
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

local function ladder(names: { string }): { UnitDefinition }
	local units: { UnitDefinition } = {}
	for _, name in names do
		table.insert(units, (assert(UNITS[name], name)))
	end
	return table.freeze(units)
end

-- Units picked by size, largest first. Time is only for tostring; durations are broken into parts instead.
local METRIC_LADDERS: { { UnitDefinition } } = table.freeze({
	ladder({ "year", "day", "hour", "minute", "second", "millisecond", "microsecond" }),
	ladder({ "kilometer", "meter", "centimeter", "millimeter" }),
	ladder({ "squareKilometer", "squareMeter", "squareCentimeter", "squareMillimeter" }),
	ladder({ "cubicMeter", "liter", "milliliter" }),
	ladder({ "gigabyte", "megabyte", "kilobyte", "byte" }),
	ladder({ "tonne", "kilogram", "gram", "milligram" }),
	ladder({ "meterPerSecondSquared" }),
	ladder({ "meganewton", "kilonewton", "newton" }),
	ladder({ "megajoule", "kilojoule", "joule" }),
	ladder({ "megawatt", "kilowatt", "watt" }),
	ladder({ "megapascal", "kilopascal", "pascal" }),
	ladder({ "kilogramPerCubicMeter" }),
	ladder({ "kelvin" }),
}) :: any

-- US customary ladders, used before the metric ones when the formatter's system is imperial
local IMPERIAL_LADDERS: { { UnitDefinition } } = table.freeze({
	ladder({ "mile", "foot", "inch" }),
	ladder({ "acre", "squareFoot" }),
	ladder({ "usGallon", "usFluidOunce" }),
	ladder({ "pound", "ounce" }),
	ladder({ "milePerHour" }),
	ladder({ "poundForce" }),
	ladder({ "poundForcePerSquareInch" }),
	ladder({ "fahrenheit" }),
}) :: any

-- Time units a rate is written per, shortest first
local PER_LADDER: { UnitDefinition } = ladder({ "second", "minute", "hour", "day", "year" })

-- Symbols for writing an unnamed compound in base units
local BASE_SYMBOLS: { [string]: string } = table.freeze({
	time = "s",
	length = "m",
	memory = "B",
	mass = "kg",
	temperature = "K",
}) :: any

--[=[
	The unit named `unit`, or nil. Takes any [UnitLike], so `"hours"` and `"h"` find `"hour"`.

	@param unit string
	@return UnitDefinition?
]=]
function MetricUnitCatalog.getUnit(unit: string): UnitDefinition?
	return UNITS[unit] or UNITS[TIME_ALIASES[unit] or ""]
end

--[=[
	The ids of every unit of `dimensions`, in a stable order: metric, then customary, then Roblox.

	@param dimensions Dimensions
	@return { UnitId }
]=]
function MetricUnitCatalog.getUnitIds(dimensions: MetricUnitDimensions.Dimensions): { UnitId }
	local found: { UnitId } = {}
	for _, unit in ORDER do
		if MetricUnitDimensions.equal(unit.dimensions, dimensions) then
			table.insert(found, unit.id)
		end
	end
	return found
end

--[=[
	The ladder of units for `dimensions`, largest first, or nil when the dimension has none. With `"imperial"`, a
	customary ladder is used where the dimension has one.

	@param dimensions Dimensions
	@param system UnitSystem?
	@return { UnitDefinition }?
]=]
function MetricUnitCatalog.getLadder(
	dimensions: MetricUnitDimensions.Dimensions,
	system: UnitSystem?
): { UnitDefinition }?
	if system == "imperial" then
		for _, units in IMPERIAL_LADDERS do
			if MetricUnitDimensions.equal(units[1].dimensions, dimensions) then
				return units
			end
		end
	end
	for _, units in METRIC_LADDERS do
		if MetricUnitDimensions.equal(units[1].dimensions, dimensions) then
			return units
		end
	end
	return nil
end

--[=[
	The largest unit on `units` that `amount` base units fills at least once, the smallest when it fills none, or
	[MetricUnitCatalog.getBaseUnit] when `amount` is zero.

	@param amount number
	@param units { UnitDefinition }
	@return UnitDefinition
]=]
function MetricUnitCatalog.pickFromLadder(amount: number, units: { UnitDefinition }): UnitDefinition
	if amount == 0 then
		return MetricUnitCatalog.getBaseUnit(units)
	end
	for _, unit in units do
		if math.abs(amount / unit.scale) >= 1 then
			return unit
		end
	end
	return units[#units]
end

--[=[
	The unit on `units` that is one SI base unit, or the smallest when none is.

	@param units { UnitDefinition }
	@return UnitDefinition
]=]
function MetricUnitCatalog.getBaseUnit(units: { UnitDefinition }): UnitDefinition
	for _, unit in units do
		if unit.scale == 1 then
			return unit
		end
	end
	return units[#units]
end

--[=[
	The shortest time unit that a rate of `amount` per second reaches at least once over, or a year when none does.

	@param amount number -- per second
	@return UnitDefinition
]=]
function MetricUnitCatalog.pickPerUnit(amount: number): UnitDefinition
	for _, unit in PER_LADDER do
		if math.abs(amount * unit.scale) >= 1 then
			return unit
		end
	end
	return PER_LADDER[#PER_LADDER]
end

--[=[
	The SI base unit symbol for a dimension name, such as `"m"` for `"length"`, or the name itself when it has none.

	@param name string
	@return string
]=]
function MetricUnitCatalog.getBaseSymbol(name: string): string
	return BASE_SYMBOLS[name] or name
end

return table.freeze(MetricUnitCatalog)
