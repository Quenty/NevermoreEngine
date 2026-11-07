--!strict
--[=[
	A measurement that knows what it measures: an amount in SI base units with integer exponents for each dimension.
	Time is held in seconds, length in metres, mass in kilograms, memory in bytes and temperature in kelvin. Derived
	quantities such as speed, force, energy and power are products of those, so `MetricUnit.newtons(1)` and
	`MetricUnit.kilograms(1) * MetricUnit.meters(1) / MetricUnit.pow(MetricUnit.seconds(1), 2)` are the same value.

	Every unit has one id, such as `"kilometer"`, used to read and write it, and one constructor, such as
	[MetricUnit.kilometers]. Read a value in any unit of its dimension with [MetricUnit.In].

	Values are frozen, and every operation returns a new one. `*` and `/` combine dimensions, a plain number scales,
	and `+`, `-`, `<`, `<=` and `==` need the same dimension on both sides. A plain `0` is zero of whatever dimension it
	meets in `+`, `-` and the helpers; any other plain number is dimensionless.

	A value is either a difference, which scales and adds freely, or absolute, a point on a scale with an offset zero
	such as a temperature in °C. Two absolutes subtract to a difference, an absolute and a difference add to an
	absolute, and an absolute cannot be added to another, negated, multiplied or divided, kelvin included.

	```lua
	local speed = MetricUnit.kilometers(36) / MetricUnit.hours(1)
	speed:In("meterPerSecond") -- 10
	speed:In("milePerHour") -- 22.37
	speed:GetKind() -- "speed"
	MetricUnit.format(speed) -- "10 m/s"

	local power = MetricUnit.kilowattHours(3) / MetricUnit.hours(1)
	power:In("kilowatt") -- 3

	local reach = MetricUnit.expect(MetricUnit.studs(357), "length", "reach") -- 100, in metres

	local swing = MetricUnit.celsiusDifference(12)
	(MetricUnit.celsius(15) + swing):In("celsius") -- 27
	(MetricUnit.celsius(15) - MetricUnit.celsius(10)):In("kelvin") -- 5
	```

	Time is elapsed time in exact seconds. [MetricUnit.years] and [MetricUnit.months] are averages for long-range math
	(a Julian year of 365.25 days, and a twelfth of it), not calendar spans; move a date by calendar months with
	`Time.add` from `@quenty/time`. [MetricUnit.InSeconds] hands exact seconds to `task.wait`, `os.time` and
	`TimeDurationUtils`. [MetricUnit.instant] makes a point in time on any epoch, and [MetricUnit.fromDateTime] and
	[MetricUnit.ToDateTime] cross to and from `DateTime`.

	[MetricUnit.format] writes a value for players, localized. `tostring` is a fixed English debug string.

	Luau cannot compare a table with a number, so `x < 0` and `x == 0` do not work; use [MetricUnit.sign] and
	[MetricUnit.isZero].

	@class MetricUnit
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnitCatalog = require("MetricUnitCatalog")
local MetricUnitDebugFormat = require("MetricUnitDebugFormat")
local MetricUnitDimensions = require("MetricUnitDimensions")
local MetricUnitFormatUtils = require("MetricUnitFormatUtils")
local MetricUnitScale = require("MetricUnitScale")

local MetricUnit = {}
MetricUnit.ClassName = "MetricUnit"
MetricUnit.__index = MetricUnit

export type Dimensions = MetricUnitDimensions.Dimensions
export type DimensionName = MetricUnitDimensions.DimensionName

--[=[
	See [MetricUnitCatalog.UnitId].

	@type UnitId MetricUnitCatalog.UnitId
	@within MetricUnit
]=]
export type UnitId = MetricUnitCatalog.UnitId

--[=[
	See [MetricUnitCatalog.UnitLike].

	@type UnitLike MetricUnitCatalog.UnitLike
	@within MetricUnit
]=]
export type UnitLike = MetricUnitCatalog.UnitLike

--[=[
	See [MetricUnitFormatUtils.MetricUnitFormatOptions].

	@type FormatOptions MetricUnitFormatUtils.MetricUnitFormatOptions
	@within MetricUnit
]=]
export type FormatOptions = MetricUnitFormatUtils.MetricUnitFormatOptions

--[=[
	See [MetricUnitFormatUtils.MetricUnitData].

	@type MetricUnitData MetricUnitFormatUtils.MetricUnitData
	@within MetricUnit
]=]
export type MetricUnitData = MetricUnitFormatUtils.MetricUnitData

-- The metatable is typed as the whole class, not `{ __index = MetricUnit }`, so that the type checker sees the
-- arithmetic and comparison metamethods.
export type MetricUnit = typeof(setmetatable(
	{} :: {
		_amount: number,
		_dimensions: Dimensions,
		_absolute: boolean,
	},
	{} :: typeof(MetricUnit)
))

local SECOND = assert(MetricUnitCatalog.getUnit("second"), "No second")

--[=[
	A dimensionless value.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.none(n: number): MetricUnit
	MetricUnit._assertNumber(n, "none")
	return MetricUnit._new(n, MetricUnitDimensions.NONE, false)
end

--[=[
	`amount` of the unit `unit`, for units chosen at runtime, such as from a config. A temperature scale gives an
	absolute temperature, as [MetricUnit.celsius] does.

	```lua
	MetricUnit.new(5, "kilometer") == MetricUnit.kilometers(5) -- true
	MetricUnit.new(90, "minutes") == MetricUnit.hours(1.5) -- true
	```

	@param amount number
	@param unit UnitLike
	@return MetricUnit
]=]
function MetricUnit.new(amount: number, unit: UnitLike): MetricUnit
	return MetricUnit._fromUnit(amount, unit, "new")
end

--[=[
	`n` microseconds.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.microseconds(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "microsecond", "microseconds")
end

--[=[
	`n` milliseconds.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.milliseconds(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "millisecond", "milliseconds")
end

--[=[
	`n` seconds.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.seconds(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "second", "seconds")
end

--[=[
	`n` minutes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.minutes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "minute", "minutes")
end

--[=[
	`n` hours.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.hours(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "hour", "hours")
end

--[=[
	`n` days of 24 hours.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.days(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "day", "days")
end

--[=[
	`n` weeks of seven days.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.weeks(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "week", "weeks")
end

--[=[
	`n` averaged months, each exactly a twelfth of an averaged year. For calendar months, use `Time.add`.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.months(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "month", "months")
end

--[=[
	`n` averaged quarters, each a quarter of an averaged year.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.quarters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "quarter", "quarters")
end

--[=[
	`n` averaged years of 365.25 days (a Julian year), for long-range elapsed time. For calendar years, use `Time.add`.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.years(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "year", "years")
end

--[=[
	`n` times a second.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perSecond(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perSecond", "perSecond")
end

--[=[
	`n` times a minute.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perMinute(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perMinute", "perMinute")
end

--[=[
	`n` times a hour.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perHour(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perHour", "perHour")
end

--[=[
	`n` times a day.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perDay(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perDay", "perDay")
end

--[=[
	`n` times a week.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perWeek(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perWeek", "perWeek")
end

--[=[
	`n` times a month.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perMonth(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perMonth", "perMonth")
end

--[=[
	`n` times a year.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.perYear(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "perYear", "perYear")
end

--[=[
	A frequency of `n` hertz, the same as [MetricUnit.perSecond].

	@param n number
	@return MetricUnit
]=]
function MetricUnit.hertz(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "hertz", "hertz")
end

--[=[
	`n` millimetres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.millimeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "millimeter", "millimeters")
end

--[=[
	`n` centimetres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.centimeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "centimeter", "centimeters")
end

--[=[
	`n` metres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.meters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "meter", "meters")
end

--[=[
	`n` kilometres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilometers(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilometer", "kilometers")
end

--[=[
	`n` inches of exactly 25.4 mm.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.inches(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "inch", "inches")
end

--[=[
	`n` feet of exactly 0.3048 m.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.feet(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "foot", "feet")
end

--[=[
	`n` yards of exactly 0.9144 m.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.yards(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "yard", "yards")
end

--[=[
	`n` miles of exactly 1,609.344 m.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.miles(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "mile", "miles")
end

--[=[
	`n` Roblox studs, 3.57 to the metre as [MetricUtils] counts them.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.studs(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "stud", "studs")
end

--[=[
	`n` square millimetres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.squareMillimeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "squareMillimeter", "squareMillimeters")
end

--[=[
	`n` square centimetres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.squareCentimeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "squareCentimeter", "squareCentimeters")
end

--[=[
	`n` square metres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.squareMeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "squareMeter", "squareMeters")
end

--[=[
	`n` hectares of 10,000 square metres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.hectares(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "hectare", "hectares")
end

--[=[
	`n` square kilometres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.squareKilometers(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "squareKilometer", "squareKilometers")
end

--[=[
	`n` square feet.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.squareFeet(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "squareFoot", "squareFeet")
end

--[=[
	`n` acres of exactly 4,046.8564224 square metres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.acres(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "acre", "acres")
end

--[=[
	`n` millilitres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.milliliters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "milliliter", "milliliters")
end

--[=[
	`n` litres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.liters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "liter", "liters")
end

--[=[
	`n` cubic metres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.cubicMeters(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "cubicMeter", "cubicMeters")
end

--[=[
	`n` US fluid ounces, each a 128th of a US gallon.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.usFluidOunces(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "usFluidOunce", "usFluidOunces")
end

--[=[
	`n` US gallons of exactly 3.785411784 litres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.usGallons(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "usGallon", "usGallons")
end

--[=[
	`n` imperial gallons of exactly 4.54609 litres.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.imperialGallons(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "imperialGallon", "imperialGallons")
end

--[=[
	`n` bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.bytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "byte", "bytes")
end

--[=[
	`n` kilobytes of 1,000 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilobytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilobyte", "kilobytes")
end

--[=[
	`n` megabytes of 1,000,000 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.megabytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "megabyte", "megabytes")
end

--[=[
	`n` gigabytes of 1,000,000,000 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.gigabytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "gigabyte", "gigabytes")
end

--[=[
	`n` kibibytes of 1,024 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kibibytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kibibyte", "kibibytes")
end

--[=[
	`n` mebibytes of 1,048,576 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.mebibytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "mebibyte", "mebibytes")
end

--[=[
	`n` gibibytes of 1,073,741,824 bytes.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.gibibytes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "gibibyte", "gibibytes")
end

--[=[
	A data rate of `n` bytes per second.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.bytesPerSecond(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "bytePerSecond", "bytesPerSecond")
end

--[=[
	A data rate of `n` kilobytes (1,000 bytes) per second.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilobytesPerSecond(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilobytePerSecond", "kilobytesPerSecond")
end

--[=[
	`n` milligrams.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.milligrams(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "milligram", "milligrams")
end

--[=[
	`n` grams.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.grams(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "gram", "grams")
end

--[=[
	`n` kilograms.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilograms(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilogram", "kilograms")
end

--[=[
	`n` tonnes of 1,000 kg.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.tonnes(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "tonne", "tonnes")
end

--[=[
	`n` avoirdupois ounces, each a sixteenth of a pound.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.ounces(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "ounce", "ounces")
end

--[=[
	`n` pounds of exactly 0.45359237 kg.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.pounds(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "pound", "pounds")
end

--[=[
	`n` stone of 14 pounds.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.stones(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "stone", "stones")
end

--[=[
	A speed of `n` metres per second.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.metersPerSecond(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "meterPerSecond", "metersPerSecond")
end

--[=[
	A speed of `n` kilometres per hour.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilometersPerHour(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilometerPerHour", "kilometersPerHour")
end

--[=[
	A speed of `n` miles per hour.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.milesPerHour(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "milePerHour", "milesPerHour")
end

--[=[
	A speed of `n` knots, nautical miles of 1,852 m per hour.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.knots(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "knot", "knots")
end

--[=[
	A speed of `n` Roblox studs per second.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.studsPerSecond(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "studPerSecond", "studsPerSecond")
end

--[=[
	An acceleration of `n` metres per second squared.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.metersPerSecondSquared(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "meterPerSecondSquared", "metersPerSecondSquared")
end

--[=[
	A force of `n` newtons.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.newtons(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "newton", "newtons")
end

--[=[
	A force of `n` kilonewtons.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilonewtons(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilonewton", "kilonewtons")
end

--[=[
	A force of `n` meganewtons.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.meganewtons(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "meganewton", "meganewtons")
end

--[=[
	A force of `n` pounds-force, a pound under standard gravity.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.poundsForce(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "poundForce", "poundsForce")
end

--[=[
	`n` joules of energy.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.joules(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "joule", "joules")
end

--[=[
	`n` kilojoules of energy.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilojoules(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilojoule", "kilojoules")
end

--[=[
	`n` megajoules of energy.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.megajoules(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "megajoule", "megajoules")
end

--[=[
	`n` kilowatt-hours of energy, each 3.6 MJ.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilowattHours(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilowattHour", "kilowattHours")
end

--[=[
	`n` kilocalories of energy (food calories), each 4,184 J.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilocalories(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilocalorie", "kilocalories")
end

--[=[
	A power of `n` watts.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.watts(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "watt", "watts")
end

--[=[
	A power of `n` kilowatts.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilowatts(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilowatt", "kilowatts")
end

--[=[
	A power of `n` megawatts.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.megawatts(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "megawatt", "megawatts")
end

--[=[
	A pressure of `n` pascals.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.pascals(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "pascal", "pascals")
end

--[=[
	A pressure of `n` kilopascals.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilopascals(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilopascal", "kilopascals")
end

--[=[
	A pressure of `n` megapascals.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.megapascals(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "megapascal", "megapascals")
end

--[=[
	A pressure of `n` bar, each 100 kPa.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.bars(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "bar", "bars")
end

--[=[
	A pressure of `n` pounds-force per square inch (psi).

	@param n number
	@return MetricUnit
]=]
function MetricUnit.poundsForcePerSquareInch(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "poundForcePerSquareInch", "poundsForcePerSquareInch")
end

--[=[
	A density of `n` kilograms per cubic metre.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kilogramsPerCubicMeter(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kilogramPerCubicMeter", "kilogramsPerCubicMeter")
end

--[=[
	A density of `n` grams per cubic centimetre, each 1,000 kg/m³.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.gramsPerCubicCentimeter(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "gramPerCubicCentimeter", "gramsPerCubicCentimeter")
end

--[=[
	The absolute temperature `n` kelvin.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kelvin(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "kelvin", "kelvin")
end

--[=[
	The absolute temperature `n` °C.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.celsius(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "celsius", "celsius")
end

--[=[
	The absolute temperature `n` °F.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.fahrenheit(n: number): MetricUnit
	return MetricUnit._fromUnit(n, "fahrenheit", "fahrenheit")
end

--[=[
	A temperature difference of `n` kelvin.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.kelvinDifference(n: number): MetricUnit
	MetricUnit._assertNumber(n, "kelvinDifference")
	return MetricUnit._new(n * MetricUnitScale.KELVIN, MetricUnitDimensions.TEMPERATURE, false)
end

--[=[
	A temperature difference of `n` °C, the same size as `n` kelvin.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.celsiusDifference(n: number): MetricUnit
	MetricUnit._assertNumber(n, "celsiusDifference")
	return MetricUnit._new(n * MetricUnitScale.CELSIUS, MetricUnitDimensions.TEMPERATURE, false)
end

--[=[
	A temperature difference of `n` °F.

	@param n number
	@return MetricUnit
]=]
function MetricUnit.fahrenheitDifference(n: number): MetricUnit
	MetricUnit._assertNumber(n, "fahrenheitDifference")
	return MetricUnit._new(n * MetricUnitScale.FAHRENHEIT, MetricUnitDimensions.TEMPERATURE, false)
end

--[=[
	How many of `unit` this is. `unit` is a unit id, any of `@quenty/time`'s names for a time unit, or another
	[MetricUnit] to take the ratio with. Errors, naming both dimensions, when they differ.

	A temperature scale reads an absolute temperature from that scale's zero and a difference as it is, and a time
	unit reads an instant as the time since its epoch. Rates read per a time unit with the `per` ids.

	```lua
	MetricUnit.kilometers(2):In("meter") -- 2000
	MetricUnit.minutes(90):In("hours") -- 1.5
	MetricUnit.perDay(48):In("perHour") -- 2
	MetricUnit.celsius(100):In("fahrenheit") -- 212
	(MetricUnit.meters(10) / MetricUnit.seconds(1)):In(MetricUnit.kilometers(1) / MetricUnit.hours(1)) -- 36
	```

	@param unit UnitLike | MetricUnit
	@return number
]=]
function MetricUnit.In(self: MetricUnit, unit: UnitLike | MetricUnit): number
	MetricUnit._assertUnit(self, "In")
	if type(unit) == "string" then
		local definition = MetricUnitCatalog.getUnit(unit)
		if not definition then
			error(string.format("MetricUnit:In knows no unit %q", unit), 2)
		end
		return MetricUnit._readUnit(self, definition)
	end

	MetricUnit._assertUnit(unit, "In")
	local other = unit :: MetricUnit
	MetricUnit._assertDifference(self, "take the ratio of")
	MetricUnit._assertDifference(other, "take the ratio of")
	if not MetricUnitDimensions.equal(self._dimensions, other._dimensions) then
		error(
			string.format(
				"MetricUnit:In cannot read %s in %s",
				MetricUnitDimensions.describe(self._dimensions),
				MetricUnitDimensions.describe(other._dimensions)
			),
			2
		)
	end
	return self._amount / other._amount
end

--[=[
	This time in exact seconds, the same as `:In("second")`: the number to hand to `task.wait`, `os.time` arithmetic
	or `TimeDurationUtils`.

	```lua
	task.wait(MetricUnit.minutes(2):InSeconds())
	TimeDurationUtils.format(MetricUnit.hours(36):InSeconds(), "h:mm") --> 36:00
	```

	@return number
]=]
function MetricUnit.InSeconds(self: MetricUnit): number
	MetricUnit._assertUnit(self, "InSeconds")
	return MetricUnit._readUnit(self, SECOND)
end

--[=[
	This value's amount in SI base units: seconds, metres, kilograms, bytes, kelvin, or their products.

	@return number
]=]
function MetricUnit.GetBaseAmount(self: MetricUnit): number
	return self._amount
end

--[=[
	This value's frozen dimension exponents, such as `{ length = 1, time = -1 }` for a speed.

	@return Dimensions
]=]
function MetricUnit.GetDimensions(self: MetricUnit): Dimensions
	return self._dimensions
end

--[=[
	What this value measures, such as `"length"`, `"speed"` or `"temperature"`, or nil for a compound without a
	name, such as length to the fourth.

	@return DimensionName?
]=]
function MetricUnit.GetKind(self: MetricUnit): DimensionName?
	return MetricUnitDimensions.getKind(self._dimensions, self._absolute)
end

--[=[
	Whether this value is of `kind`, a [DimensionName] or a table of exponents.

	@param kind DimensionName | Dimensions
	@return boolean
]=]
function MetricUnit.IsKind(self: MetricUnit, kind: DimensionName | Dimensions): boolean
	return MetricUnit.isKind(self, kind)
end

--[=[
	Whether this value is absolute, a point on a scale such as a temperature, rather than a difference.

	@return boolean
]=]
function MetricUnit.IsAbsolute(self: MetricUnit): boolean
	return self._absolute
end

--[=[
	The ids of every unit this value can be read in or formatted as, for a settings menu to offer. Metric units come
	first, then US customary ones, then Roblox studs.

	```lua
	MetricUnit.meters(1):GetUnitIds() -- { "millimeter", "centimeter", "meter", "kilometer", "inch", ... }
	```

	@return { UnitId }
]=]
function MetricUnit.GetUnitIds(self: MetricUnit): { UnitId }
	return MetricUnitCatalog.getUnitIds(self._dimensions)
end

--[=[
	Whether `value` is a [MetricUnit].

	@param value any
	@return boolean
]=]
function MetricUnit.isUnit(value: any): boolean
	return type(value) == "table" and getmetatable(value) == MetricUnit
end

--[=[
	Whether `value` is a [MetricUnit] of `kind`, a [DimensionName] or a table of exponents. Safe to call on anything.
	Errors on an unknown name, so a typo does not quietly answer false.

	```lua
	MetricUnit.isKind(MetricUnit.kilometers(1) / MetricUnit.hours(1), "speed") -- true
	MetricUnit.isKind(MetricUnit.celsius(5), "temperature") -- true, absolute
	MetricUnit.isKind(MetricUnit.celsiusDifference(5), "temperatureDifference") -- true
	MetricUnit.isKind(5, "length") -- false
	```

	@param value any
	@param kind DimensionName | Dimensions
	@return boolean
]=]
function MetricUnit.isKind(value: any, kind: DimensionName | Dimensions): boolean
	local dimensions, absolute = MetricUnitDimensions.fromName(kind)
	return MetricUnit.isUnit(value)
		and value._absolute == absolute
		and MetricUnitDimensions.equal(value._dimensions, dimensions)
end

--[=[
	The amount of `value` in SI base units, for checking arguments at an API boundary. Errors with `slot`, the
	dimension expected and the one given if `value` is not of `kind`. A plain 0 is zero of any kind but an absolute
	one.

	```lua
	local function setReach(reach: MetricUnit.MetricUnit | number)
		local meters = MetricUnit.expect(reach, "length", "reach")
	end
	```

	@param value MetricUnit | number
	@param kind DimensionName | Dimensions
	@param slot string -- what the value is for, used in the error
	@return number -- in SI base units
]=]
function MetricUnit.expect(value: MetricUnit | number, kind: DimensionName | Dimensions, slot: string): number
	local dimensions, absolute = MetricUnitDimensions.fromName(kind)
	if type(value) == "number" then
		if value == 0 and not absolute then
			return 0
		elseif not absolute and next(dimensions) == nil then
			return value
		end
		error(
			string.format(
				"MetricUnit.expect: %s expects %s, got the plain number %s",
				slot,
				MetricUnitDimensions.describeKind(dimensions, absolute),
				tostring(value)
			),
			2
		)
	end
	if not MetricUnit.isUnit(value) then
		error(
			string.format(
				"MetricUnit.expect: %s expects %s, got %s",
				slot,
				MetricUnitDimensions.describeKind(dimensions, absolute),
				typeof(value)
			),
			2
		)
	end
	local unit = value :: MetricUnit
	if unit._absolute ~= absolute or not MetricUnitDimensions.equal(unit._dimensions, dimensions) then
		error(
			string.format(
				"MetricUnit.expect: %s expects %s, got %s",
				slot,
				MetricUnitDimensions.describeKind(dimensions, absolute),
				MetricUnitDimensions.describeKind(unit._dimensions, unit._absolute)
			),
			2
		)
	end
	return unit._amount
end

--[=[
	Whether `a` and `b` have the same dimensions; a plain 0 has every dimension and any other number none.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return boolean
]=]
function MetricUnit.sameDimension(a: MetricUnit | number, b: MetricUnit | number): boolean
	if a == 0 or b == 0 then
		return true
	end
	return MetricUnitDimensions.equal(MetricUnit._dimensionsOf(a), MetricUnit._dimensionsOf(b))
end

--[=[
	Whether `value` is zero.

	@param value MetricUnit | number
	@return boolean
]=]
function MetricUnit.isZero(value: MetricUnit | number): boolean
	if type(value) == "number" then
		return value == 0
	end
	MetricUnit._assertUnit(value, "isZero")
	return value._amount == 0
end

--[=[
	-1, 0 or 1 as `value` is negative, zero or positive; an absolute temperature is measured from absolute zero.

	@param value MetricUnit | number
	@return number
]=]
function MetricUnit.sign(value: MetricUnit | number): number
	if type(value) == "number" then
		return math.sign(value)
	end
	MetricUnit._assertUnit(value, "sign")
	return math.sign(value._amount)
end

--[=[
	The smallest of `...`, all of one dimension.

	@param ... MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.min(...: MetricUnit | number): MetricUnit
	return MetricUnit._extreme("min", math.min, ...)
end

--[=[
	The largest of `...`, all of one dimension.

	@param ... MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.max(...: MetricUnit | number): MetricUnit
	return MetricUnit._extreme("max", math.max, ...)
end

--[=[
	`value` held between `low` and `high`, all of one dimension.

	@param value MetricUnit | number
	@param low MetricUnit | number
	@param high MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.clamp(value: MetricUnit | number, low: MetricUnit | number, high: MetricUnit | number): MetricUnit
	return MetricUnit.min(MetricUnit.max(value, low), high)
end

--[=[
	The size of `value`, a difference.

	@param value MetricUnit
	@return MetricUnit
]=]
function MetricUnit.abs(value: MetricUnit): MetricUnit
	MetricUnit._assertUnit(value, "abs")
	MetricUnit._assertDifference(value, "take the size of")
	return MetricUnit._new(math.abs(value._amount), value._dimensions, false)
end

--[=[
	The square root of `value`, halving its exponents, erroring if any is odd.

	@param value MetricUnit
	@return MetricUnit
]=]
function MetricUnit.sqrt(value: MetricUnit): MetricUnit
	MetricUnit._assertUnit(value, "sqrt")
	MetricUnit._assertDifference(value, "take the square root of")
	if value._amount < 0 then
		error(string.format("MetricUnit.sqrt of a negative %s", MetricUnitDimensions.describe(value._dimensions)), 2)
	end
	return MetricUnit._new(math.sqrt(value._amount), MetricUnitDimensions.scale(value._dimensions, 0.5), false)
end

--[=[
	`value` to the whole power `power`, multiplying its exponents.

	@param value MetricUnit
	@param power number -- a whole number
	@return MetricUnit
]=]
function MetricUnit.pow(value: MetricUnit, power: number): MetricUnit
	MetricUnit._assertUnit(value, "pow")
	MetricUnit._assertDifference(value, "exponentiate")
	if type(power) ~= "number" or power ~= math.floor(power) then
		error(string.format("MetricUnit.pow takes a whole power, not %s", tostring(power)), 2)
	end
	return MetricUnit._new(value._amount ^ power, MetricUnitDimensions.scale(value._dimensions, power), false)
end

--[=[
	Whether `a` and `b`, of one dimension, are within `epsilon` of each other. `epsilon` is a [MetricUnit] of their
	dimension, or a plain number in SI base units (1e-9 by default).

	@param a MetricUnit | number
	@param b MetricUnit | number
	@param epsilon (MetricUnit | number)?
	@return boolean
]=]
function MetricUnit.fuzzyEq(a: MetricUnit | number, b: MetricUnit | number, epsilon: (MetricUnit | number)?): boolean
	local aAmount, bAmount, dimensions = MetricUnit._pair(a, b, "compare")
	local tolerance = 1e-9
	if epsilon ~= nil then
		if type(epsilon) == "number" then
			tolerance = epsilon
		else
			tolerance = MetricUnit.expect(epsilon, dimensions, "fuzzyEq's epsilon")
		end
	end
	return math.abs(aAmount - bAmount) <= tolerance
end

--[=[
	`value` as plain data, for saves.

	@param value MetricUnit
	@return MetricUnitData
]=]
function MetricUnit.toData(value: MetricUnit): MetricUnitData
	MetricUnit._assertUnit(value, "toData")
	return {
		amount = value._amount,
		dimensions = table.clone(value._dimensions),
		absolute = if value._absolute then true else nil,
	}
end

--[=[
	The [MetricUnit] that `data` from [MetricUnit.toData] holds.

	@param data MetricUnitData
	@return MetricUnit
]=]
function MetricUnit.fromData(data: MetricUnitData): MetricUnit
	if
		type(data) ~= "table"
		or type(data.amount) ~= "number"
		or not MetricUnitDimensions.isDimensions(data.dimensions)
	then
		error("MetricUnit.fromData takes { amount: number, dimensions: { [string]: integer }, absolute: boolean? }", 2)
	end
	return MetricUnit._new(data.amount, table.freeze(table.clone(data.dimensions)), data.absolute == true)
end

--[=[
	Text for players, localized, in a unit that suits the size. See [MetricUnitFormatUtils.format] for the options.
	An instant is written as the time since its epoch, since only the caller knows what the epoch is; for a calendar
	date, use `Time.format(x:ToDateTime(), ...)` from `@quenty/time`.

	```lua
	MetricUnit.format(MetricUnit.meters(2500)) --> 2.5 km
	MetricUnit.format(MetricUnit.meters(2500), { unitDisplay = "long", locale = "en-gb" }) --> 2.5 kilometres
	MetricUnit.format(MetricUnit.kilometersPerHour(90), { unit = "kilometerPerHour" }) --> 90 km/h
	MetricUnit.format(MetricUnit.kilometers(5), { system = "imperial" }) --> 3.107 mi
	MetricUnit.format(MetricUnit.years(1)) --> 1 year
	MetricUnit.format(MetricUnit.minutes(90), { locale = "es-es" }) --> 1 hora, 30 minutos
	```

	@param value MetricUnit
	@param options FormatOptions?
	@return string
]=]
function MetricUnit.format(value: MetricUnit, options: FormatOptions?): string
	MetricUnit._assertUnit(value, "format")
	return MetricUnitFormatUtils.format(value, options)
end

--[=[
	The instant `seconds` after an epoch: a point in time rather than a span of it. The epoch is whatever the caller
	measures from, such as a simulation's start; [MetricUnit.fromDateTime] uses the Unix epoch. Instants follow the
	same rules as absolute temperatures: two subtract to a span, an instant and a span add to an instant, and an
	instant cannot be added to another, scaled or negated. Instants from different epochs must not be mixed; nothing
	can check that for you.

	```lua
	local worldStart = MetricUnit.instant(0)
	local now = worldStart + MetricUnit.years(250)
	(now - worldStart):In("year") -- 250
	now:In("year") -- 250, time since its epoch
	```

	@param seconds number -- since the epoch
	@return MetricUnit
]=]
function MetricUnit.instant(seconds: number): MetricUnit
	MetricUnit._assertNumber(seconds, "instant")
	return MetricUnit._new(seconds * MetricUnitScale.SECOND, MetricUnitDimensions.TIME, true)
end

--[=[
	The instant `dateTime` marks, measured from the Unix epoch, to the millisecond. Subtract two for the exact time
	between them, which counts calendar months and leap days at their real length.

	```lua
	local played = MetricUnit.fromDateTime(DateTime.now()) - MetricUnit.fromDateTime(joinedAt)
	```

	@param dateTime DateTime
	@return MetricUnit
]=]
function MetricUnit.fromDateTime(dateTime: DateTime): MetricUnit
	if typeof(dateTime) ~= "DateTime" then
		error(string.format("MetricUnit.fromDateTime takes a DateTime, not %s", typeof(dateTime)), 2)
	end
	return MetricUnit._new(
		dateTime.UnixTimestampMillis / 1000 * MetricUnitScale.SECOND,
		MetricUnitDimensions.TIME,
		true
	)
end

--[=[
	This instant as a `DateTime`, to the nearest millisecond, taking its epoch to be the Unix epoch as
	[MetricUnit.fromDateTime] does. Errors on anything but an instant. To move a date by exact time, add a span:
	`(MetricUnit.fromDateTime(dateTime) + MetricUnit.days(7)):ToDateTime()`. To move by calendar months, use
	`Time.add` from `@quenty/time`.

	@return DateTime
]=]
function MetricUnit.ToDateTime(self: MetricUnit): DateTime
	MetricUnit._assertUnit(self, "ToDateTime")
	if not (self._absolute and MetricUnitDimensions.equal(self._dimensions, MetricUnitDimensions.TIME)) then
		error(
			string.format(
				"MetricUnit:ToDateTime takes an instant, not %s",
				MetricUnitDimensions.describeKind(self._dimensions, self._absolute)
			),
			2
		)
	end
	local seconds = self._amount / MetricUnitScale.SECOND
	return DateTime.fromUnixTimestampMillis(math.floor(seconds * 1000 + 0.5))
end

--[=[
	The sum of two values of one dimension; an absolute and a difference give an absolute.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__add(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, bAmount, dimensions, aAbsolute, bAbsolute = MetricUnit._pair(a, b, "add")
	if aAbsolute and bAbsolute then
		error(
			string.format(
				"MetricUnit: cannot add two %ss; subtract them for a difference, or add a difference to one",
				MetricUnitDimensions.describeKind(dimensions, true)
			),
			2
		)
	end
	return MetricUnit._new(aAmount + bAmount, dimensions, aAbsolute or bAbsolute)
end

--[=[
	The difference of two values of one dimension; two absolutes give a difference.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__sub(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, bAmount, dimensions, aAbsolute, bAbsolute = MetricUnit._pair(a, b, "subtract")
	if bAbsolute and not aAbsolute then
		error(
			string.format(
				"MetricUnit: cannot subtract an %s from a %s",
				MetricUnitDimensions.describeKind(dimensions, true),
				MetricUnitDimensions.describeKind(dimensions, false)
			),
			2
		)
	end
	return MetricUnit._new(aAmount - bAmount, dimensions, aAbsolute and not bAbsolute)
end

--[=[
	The product, combining dimensions; a plain number scales.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__mul(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, aDimensions = MetricUnit._scalable(a, "multiply")
	local bAmount, bDimensions = MetricUnit._scalable(b, "multiply")
	return MetricUnit._new(aAmount * bAmount, MetricUnitDimensions.combine(aDimensions, bDimensions, 1), false)
end

--[=[
	The quotient, combining dimensions; a plain number scales, or over a unit inverts it.

	@param a MetricUnit | number
	@param b MetricUnit | number
	@return MetricUnit
]=]
function MetricUnit.__div(a: MetricUnit | number, b: MetricUnit | number): MetricUnit
	local aAmount, aDimensions = MetricUnit._scalable(a, "divide")
	local bAmount, bDimensions = MetricUnit._scalable(b, "divide")
	return MetricUnit._new(aAmount / bAmount, MetricUnitDimensions.combine(aDimensions, bDimensions, -1), false)
end

--[=[
	The negation of a difference.

	@param a MetricUnit
	@return MetricUnit
]=]
function MetricUnit.__unm(a: MetricUnit): MetricUnit
	MetricUnit._assertDifference(a, "negate")
	return MetricUnit._new(-a._amount, a._dimensions, false)
end

--[=[
	Whether `a` is less than `b`, both of one kind.

	@param a MetricUnit
	@param b MetricUnit
	@return boolean
]=]
function MetricUnit.__lt(a: MetricUnit, b: MetricUnit): boolean
	local aAmount, bAmount = MetricUnit._pair(a, b, "compare")
	return aAmount < bAmount
end

--[=[
	Whether `a` is at most `b`, both of one kind.

	@param a MetricUnit
	@param b MetricUnit
	@return boolean
]=]
function MetricUnit.__le(a: MetricUnit, b: MetricUnit): boolean
	local aAmount, bAmount = MetricUnit._pair(a, b, "compare")
	return aAmount <= bAmount
end

--[=[
	Whether `a` equals `b`, both of one kind.

	@param a MetricUnit
	@param b MetricUnit
	@return boolean
]=]
function MetricUnit.__eq(a: MetricUnit, b: MetricUnit): boolean
	local aAmount, bAmount = MetricUnit._pair(a, b, "compare")
	return aAmount == bAmount
end

--[=[
	English debug text that never changes with the locale, such as "10 m/s", "3.5 d", "2.5 kW" or "1.6 MB". Use
	[MetricUnit.format] for text a player reads.

	@return string
]=]
function MetricUnit.__tostring(self: MetricUnit): string
	return MetricUnitDebugFormat.format(self._amount, self._dimensions, self._absolute)
end

function MetricUnit._new(amount: number, dimensions: Dimensions, absolute: boolean): MetricUnit
	local unit: MetricUnit = setmetatable({} :: any, MetricUnit)
	unit._amount = amount
	unit._dimensions = dimensions
	unit._absolute = absolute
	table.freeze(unit :: any)
	return unit
end

-- `n` of a unit: an absolute temperature for a temperature scale, a difference otherwise
function MetricUnit._fromUnit(n: number, unit: string, name: string): MetricUnit
	MetricUnit._assertNumber(n, name)
	local definition = MetricUnitCatalog.getUnit(unit)
	if not definition then
		error(string.format("MetricUnit.%s knows no unit %q", name, tostring(unit)), 3)
	end
	if definition.zero ~= nil then
		return MetricUnit._new(n * definition.scale + definition.zero, definition.dimensions, true)
	end
	return MetricUnit._new(n * definition.scale, definition.dimensions, false)
end

function MetricUnit._assertNumber(n: any, name: string)
	if type(n) ~= "number" then
		error(string.format("MetricUnit.%s takes a number, not %s", name, typeof(n)), 4)
	end
end

function MetricUnit._assertUnit(value: any, name: string)
	if not MetricUnit.isUnit(value) then
		error(string.format("MetricUnit.%s takes a MetricUnit, not %s", name, typeof(value)), 4)
	end
end

function MetricUnit._assertDifference(value: MetricUnit, verb: string)
	if value._absolute then
		error(
			string.format(
				"MetricUnit: cannot %s an %s; subtract another to get a difference",
				verb,
				MetricUnitDimensions.describeKind(value._dimensions, true)
			),
			4
		)
	end
end

-- Reads in one unit: a temperature scale from its zero when absolute, anything else only as a difference
function MetricUnit._readUnit(self: MetricUnit, definition: MetricUnitCatalog.UnitDefinition): number
	if definition.zero ~= nil then
		if not MetricUnitDimensions.equal(self._dimensions, definition.dimensions) then
			error(
				string.format(
					"MetricUnit:In(%q) reads temperature, not %s",
					definition.id,
					MetricUnitDimensions.describeKind(self._dimensions, self._absolute)
				),
				3
			)
		end
		local amount = if self._absolute then self._amount - definition.zero else self._amount
		return amount / definition.scale
	end

	-- An instant reads as the time since its epoch, as a temperature scale reads from its zero
	local isInstantRead = self._absolute and definition.duration
	if
		(self._absolute and not isInstantRead)
		or not MetricUnitDimensions.equal(self._dimensions, definition.dimensions)
	then
		error(
			string.format(
				"MetricUnit:In(%q) reads %s, not %s",
				definition.id,
				MetricUnitDimensions.describe(definition.dimensions),
				MetricUnitDimensions.describeKind(self._dimensions, self._absolute)
			),
			3
		)
	end
	return self._amount / definition.scale
end

function MetricUnit._dimensionsOf(value: MetricUnit | number): Dimensions
	if type(value) == "number" then
		return MetricUnitDimensions.NONE
	end
	MetricUnit._assertUnit(value, "sameDimension")
	return value._dimensions
end

function MetricUnit._scalable(value: MetricUnit | number, verb: string): (number, Dimensions)
	if type(value) == "number" then
		return value, MetricUnitDimensions.NONE
	end
	MetricUnit._assertUnit(value, verb)
	MetricUnit._assertDifference(value, verb)
	return value._amount, value._dimensions
end

function MetricUnit._pair(
	a: MetricUnit | number,
	b: MetricUnit | number,
	verb: string
): (number, number, Dimensions, boolean, boolean)
	if type(a) == "number" and type(b) == "number" then
		return a, b, MetricUnitDimensions.NONE, false, false
	elseif type(a) == "number" then
		MetricUnit._assertUnit(b, verb)
		local unit = b :: MetricUnit
		return a, unit._amount, MetricUnit._numberDimensions(a, unit, verb), false, unit._absolute
	elseif type(b) == "number" then
		MetricUnit._assertUnit(a, verb)
		return a._amount, b, MetricUnit._numberDimensions(b, a, verb), a._absolute, false
	end
	MetricUnit._assertUnit(a, verb)
	MetricUnit._assertUnit(b, verb)
	if not MetricUnitDimensions.equal(a._dimensions, b._dimensions) then
		error(
			string.format(
				"MetricUnit: cannot %s %s and %s",
				verb,
				MetricUnitDimensions.describeKind(a._dimensions, a._absolute),
				MetricUnitDimensions.describeKind(b._dimensions, b._absolute)
			),
			3
		)
	end
	if verb == "compare" and a._absolute ~= b._absolute then
		error(
			string.format(
				"MetricUnit: cannot compare an %s and a %s",
				MetricUnitDimensions.describeKind(a._dimensions, true),
				MetricUnitDimensions.describeKind(a._dimensions, false)
			),
			3
		)
	end
	return a._amount, b._amount, a._dimensions, a._absolute, b._absolute
end

function MetricUnit._numberDimensions(n: number, unit: MetricUnit, verb: string): Dimensions
	if n == 0 and not (verb == "compare" and unit._absolute) then
		return unit._dimensions
	elseif next(unit._dimensions) == nil and not unit._absolute then
		return unit._dimensions
	end
	error(
		string.format(
			"MetricUnit: cannot %s %s and the plain number %s",
			verb,
			MetricUnitDimensions.describeKind(unit._dimensions, unit._absolute),
			tostring(n)
		),
		4
	)
end

function MetricUnit._extreme(name: string, pick: (number, number) -> number, ...: MetricUnit | number): MetricUnit
	local count = select("#", ...)
	if count == 0 then
		error(string.format("MetricUnit.%s takes at least one value", name), 3)
	end
	local reference: MetricUnit | number = 0
	for index = 1, count do
		local value = select(index, ...)
		if value ~= 0 then
			reference = value
			break
		end
	end
	local bestAmount, _, dimensions, absolute = MetricUnit._pair(select(1, ...), reference, "compare")
	for index = 2, count do
		local amount = MetricUnit._pair(select(index, ...), reference, "compare")
		bestAmount = pick(bestAmount, amount)
	end
	return MetricUnit._new(bestAmount, dimensions, absolute)
end

return MetricUnit
